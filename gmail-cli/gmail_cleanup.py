#!/usr/bin/env python3
"""
Gmail CLI Cleanup Tool
Filter and delete Gmail messages from the command line.

Usage:
    python gmail_cleanup.py --query "from:spam@example.com" --dry-run
    python gmail_cleanup.py --query "older_than:1y label:promotions" --delete
    python gmail_cleanup.py --query "from:newsletter@site.com" --delete --no-confirm
"""

import argparse
import json
import os
import sys
from datetime import datetime

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying scopes, delete token.json
SCOPES = ['https://mail.google.com/']

CREDENTIALS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'credentials.json')
TOKEN_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'token.json')
TIDY_RULES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tidy-rules.json')


def get_gmail_service():
    """Authenticate and return Gmail API service."""
    creds = None
    
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CREDENTIALS_FILE):
                print(f"Error: {CREDENTIALS_FILE} not found.")
                print("Download OAuth credentials from Google Cloud Console.")
                sys.exit(1)
            
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())
    
    return build('gmail', 'v1', credentials=creds)


def search_messages(service, query, max_results=500):
    """Search for messages matching the query."""
    messages = []
    page_token = None
    
    print(f"Searching for messages matching: {query}")
    
    while True:
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=min(max_results - len(messages), 500),
            pageToken=page_token
        ).execute()
        
        if 'messages' in results:
            messages.extend(results['messages'])
            print(f"  Found {len(messages)} messages so far...")
        
        if len(messages) >= max_results:
            break
            
        page_token = results.get('nextPageToken')
        if not page_token:
            break
    
    return messages


def get_message_details(service, message_id):
    """Get subject, from, and date for a message."""
    try:
        msg = service.users().messages().get(
            userId='me',
            id=message_id,
            format='metadata',
            metadataHeaders=['Subject', 'From', 'Date']
        ).execute()
        
        headers = {h['name']: h['value'] for h in msg.get('payload', {}).get('headers', [])}
        
        return {
            'id': message_id,
            'subject': headers.get('Subject', '(no subject)')[:60],
            'from': headers.get('From', '(unknown)')[:40],
            'date': headers.get('Date', '(unknown date)')[:25]
        }
    except HttpError:
        return {'id': message_id, 'subject': '(error)', 'from': '(error)', 'date': '(error)'}


def preview_messages(service, messages, limit=10):
    """Show preview of messages."""
    print(f"\nShowing first {min(limit, len(messages))} of {len(messages)} messages:\n")
    print("-" * 100)
    
    for msg in messages[:limit]:
        details = get_message_details(service, msg['id'])
        print(f"From: {details['from']}")
        print(f"Subject: {details['subject']}")
        print(f"Date: {details['date']}")
        print("-" * 100)


def delete_messages(service, messages, batch_size=100):
    """Delete messages in batches."""
    total = len(messages)
    deleted = 0
    
    print(f"\nDeleting {total} messages...")
    
    for i in range(0, total, batch_size):
        batch = messages[i:i + batch_size]
        message_ids = [msg['id'] for msg in batch]
        
        try:
            service.users().messages().batchDelete(
                userId='me',
                body={'ids': message_ids}
            ).execute()
            deleted += len(batch)
            print(f"  Deleted {deleted}/{total} messages...")
        except HttpError as e:
            print(f"  Error deleting batch: {e}")
    
    print(f"\nDone! Deleted {deleted} messages.")
    return deleted


def trash_messages(service, messages, batch_size=100):
    """Move messages to trash in batches (recoverable)."""
    total = len(messages)
    trashed = 0

    print(f"\nMoving {total} messages to trash...")

    for i in range(0, total, batch_size):
        batch = messages[i:i + batch_size]
        message_ids = [msg['id'] for msg in batch]

        try:
            service.users().messages().batchModify(
                userId='me',
                body={
                    'ids': message_ids,
                    'addLabelIds': ['TRASH'],
                    'removeLabelIds': ['INBOX']
                }
            ).execute()
            trashed += len(batch)
            print(f"  Trashed {trashed}/{total} messages...")
        except HttpError as e:
            print(f"  Error trashing batch: {e}")

    print(f"\nDone! Moved {trashed} messages to trash.")
    return trashed


def get_or_create_label(service, label_name):
    """Get existing label ID or create new label."""
    try:
        results = service.users().labels().list(userId='me').execute()
        labels = results.get('labels', [])

        for label in labels:
            if label['name'].lower() == label_name.lower():
                return label['id']

        # Label doesn't exist, create it
        label_body = {
            'name': label_name,
            'labelListVisibility': 'labelShow',
            'messageListVisibility': 'show'
        }
        created = service.users().labels().create(userId='me', body=label_body).execute()
        print(f"Created new label: {label_name}")
        return created['id']
    except HttpError as e:
        # Handle 409 conflict - label exists but wasn't matched (case/normalization differences)
        if e.resp.status == 409:
            try:
                results = service.users().labels().list(userId='me').execute()
                labels = results.get('labels', [])
                for label in labels:
                    if label['name'].lower() == label_name.lower():
                        return label['id']
            except HttpError:
                pass
        print(f"Error getting/creating label: {e}")
        return None


def label_and_archive_messages(service, messages, label_name, batch_size=100):
    """Apply label and remove from inbox (archive) in batches."""
    total = len(messages)
    processed = 0

    label_id = get_or_create_label(service, label_name)
    if not label_id:
        print("Error: Could not get or create label")
        return 0

    print(f"\nLabeling {total} messages with '{label_name}' and archiving...")

    for i in range(0, total, batch_size):
        batch = messages[i:i + batch_size]
        message_ids = [msg['id'] for msg in batch]

        try:
            service.users().messages().batchModify(
                userId='me',
                body={
                    'ids': message_ids,
                    'addLabelIds': [label_id],
                    'removeLabelIds': ['INBOX']
                }
            ).execute()
            processed += len(batch)
            print(f"  Processed {processed}/{total} messages...")
        except HttpError as e:
            print(f"  Error processing batch: {e}")

    print(f"\nDone! Labeled and archived {processed} messages.")
    return processed


def run_tidy_rules(service, dry_run=False, no_confirm=False, max_results=500):
    """Process all tidy rules from config file."""
    if not os.path.exists(TIDY_RULES_FILE):
        print(f"Error: {TIDY_RULES_FILE} not found.")
        print("Create a tidy-rules.json file with your filing rules.")
        return

    with open(TIDY_RULES_FILE, 'r') as f:
        config = json.load(f)

    rules = config.get('rules', [])
    if not rules:
        print("No rules found in tidy-rules.json")
        return

    total_processed = 0

    for rule in rules:
        label = rule.get('label')
        from_patterns = rule.get('from', [])

        if not label or not from_patterns:
            continue

        # Build query: in:inbox AND {from:pattern1 from:pattern2 ...}
        from_clauses = ' '.join([f'from:{p}' for p in from_patterns])
        query = f'in:inbox {{{from_clauses}}}'

        print(f"\n{'='*60}")
        print(f"Rule: {label}")
        print(f"Query: {query}")
        print('='*60)

        messages = search_messages(service, query, max_results)

        if not messages:
            print("No messages found for this rule.")
            continue

        # Show preview
        preview_messages(service, messages, limit=5)

        if dry_run:
            print(f"\n[DRY RUN] Would label and archive {len(messages)} messages as '{label}'")
            continue

        if not no_confirm:
            response = input(f"\nLabel {len(messages)} messages as '{label}' and archive? [y/N]: ")
            if response.lower() != 'y':
                print("Skipped.")
                continue

        count = label_and_archive_messages(service, messages, label)
        total_processed += count

    print(f"\n{'='*60}")
    print(f"Tidy complete! Processed {total_processed} messages total.")
    print('='*60)


def main():
    parser = argparse.ArgumentParser(
        description='Filter and delete Gmail messages from the command line.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --query "from:spam@example.com" --dry-run
  %(prog)s --query "older_than:1y label:promotions" --delete
  %(prog)s --query "from:newsletter@site.com" --trash
  %(prog)s --query "subject:unsubscribe older_than:6m" --delete --no-confirm

Gmail search operators:
  from:sender@email.com      Messages from specific sender
  to:recipient@email.com     Messages to specific recipient  
  subject:word               Messages with word in subject
  older_than:1y              Older than 1 year (use d/m/y)
  newer_than:1m              Newer than 1 month
  label:promotions           Messages with specific label
  is:unread                  Unread messages
  has:attachment             Messages with attachments
  larger:5M                  Larger than 5MB
        """
    )
    
    parser.add_argument('--query', '-q', help='Gmail search query')
    parser.add_argument('--tidy', action='store_true', help='Run all tidy rules from tidy-rules.json')
    parser.add_argument('--dry-run', '-n', action='store_true', help='Preview only, no deletion')
    parser.add_argument('--delete', '-d', action='store_true', help='Permanently delete messages')
    parser.add_argument('--trash', '-t', action='store_true', help='Move messages to trash (recoverable)')
    parser.add_argument('--label', '-l', metavar='LABEL', help='Apply label and archive (remove from inbox)')
    parser.add_argument('--no-confirm', '-y', action='store_true', help='Skip confirmation prompt')
    parser.add_argument('--max', '-m', type=int, default=500, help='Maximum messages to process (default: 500)')
    parser.add_argument('--preview', '-p', type=int, default=10, help='Number of messages to preview (default: 10)')
    
    args = parser.parse_args()

    # Handle tidy mode separately
    if args.tidy:
        try:
            service = get_gmail_service()
            run_tidy_rules(service, args.dry_run, args.no_confirm, args.max)
        except HttpError as e:
            print(f"Gmail API error: {e}")
            sys.exit(1)
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(1)
        sys.exit(0)

    if not args.query:
        print("Error: --query is required (or use --tidy)")
        sys.exit(1)

    if not args.dry_run and not args.delete and not args.trash and not args.label:
        print("Error: Specify --dry-run, --delete, --trash, or --label <name>")
        sys.exit(1)

    action_count = sum([args.delete, args.trash, bool(args.label)])
    if action_count > 1:
        print("Error: Cannot use multiple actions (--delete, --trash, --label)")
        sys.exit(1)
    
    try:
        service = get_gmail_service()
        messages = search_messages(service, args.query, args.max)
        
        if not messages:
            print("\nNo messages found matching your query.")
            sys.exit(0)
        
        preview_messages(service, messages, args.preview)
        
        if args.dry_run:
            print(f"\n[DRY RUN] Would affect {len(messages)} messages.")
            print("Run with --delete, --trash, or --label to actually process them.")
            sys.exit(0)

        if not args.no_confirm:
            if args.delete:
                action = "permanently DELETE"
            elif args.trash:
                action = "move to TRASH"
            else:
                action = f"label with '{args.label}' and ARCHIVE"
            response = input(f"\n{action.upper()} {len(messages)} messages? [y/N]: ")
            if response.lower() != 'y':
                print("Cancelled.")
                sys.exit(0)

        if args.delete:
            delete_messages(service, messages)
        elif args.trash:
            trash_messages(service, messages)
        else:
            label_and_archive_messages(service, messages, args.label)
            
    except HttpError as e:
        print(f"Gmail API error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(1)


if __name__ == '__main__':
    main()
