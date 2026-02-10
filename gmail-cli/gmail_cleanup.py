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
import base64
import json
import os
import re
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
            try:
                creds.refresh(Request())
            except Exception:
                creds = None
        if not creds or not creds.valid:
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


def list_labels(service):
    """List all Gmail labels with message counts."""
    try:
        results = service.users().labels().list(userId='me').execute()
        labels = results.get('labels', [])
    except HttpError as e:
        print(f"Error listing labels: {e}")
        return

    if not labels:
        print("No labels found.")
        return

    # Fetch full details for each label to get message counts
    detailed = []
    for label in labels:
        try:
            info = service.users().labels().get(userId='me', id=label['id']).execute()
            detailed.append(info)
        except HttpError:
            detailed.append(label)

    detailed.sort(key=lambda l: l['name'].lower())

    print(f"\n{'Label':<40} {'Total':>8} {'Unread':>8}")
    print("-" * 58)
    for label in detailed:
        name = label['name']
        total = label.get('messagesTotal', '-')
        unread = label.get('messagesUnread', '-')
        print(f"{name:<40} {str(total):>8} {str(unread):>8}")
    print(f"\n{len(detailed)} labels total.")


def get_messages_by_label(service, label_name, max_results=500):
    """Fetch messages with a given label name."""
    # Resolve label name to ID
    try:
        results = service.users().labels().list(userId='me').execute()
        labels = results.get('labels', [])
    except HttpError as e:
        print(f"Error listing labels: {e}")
        return None

    label_id = None
    for label in labels:
        if label['name'].lower() == label_name.lower():
            label_id = label['id']
            break

    if not label_id:
        print(f"Error: Label '{label_name}' not found.")
        print("Use --labels to see available labels.")
        return None

    print(f"Fetching messages with label: {label_name}")

    messages = []
    page_token = None

    while True:
        results = service.users().messages().list(
            userId='me',
            labelIds=[label_id],
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
        raw_query = rule.get('query')

        if not label or (not from_patterns and not raw_query):
            continue

        # Build query from 'from' patterns or use raw 'query'
        if raw_query:
            query = f'in:inbox {raw_query}'
        else:
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


def sanitize_filename(filename):
    """Replace unsafe characters in filenames with underscores."""
    return re.sub(r'[/\\:*?"<>|]', '_', filename)


def get_unique_path(directory, filename):
    """Return a path in directory for filename, appending _1, _2 etc. to avoid overwrites."""
    path = os.path.join(directory, filename)
    if not os.path.exists(path):
        return path
    name, ext = os.path.splitext(filename)
    counter = 1
    while True:
        new_path = os.path.join(directory, f"{name}_{counter}{ext}")
        if not os.path.exists(new_path):
            return new_path
        counter += 1


def format_size(size_bytes):
    """Format bytes as human-readable string."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.1f} MB"


def get_message_attachments(service, message_id):
    """Fetch message and return list of attachment dicts from all MIME parts."""
    try:
        msg = service.users().messages().get(
            userId='me', id=message_id, format='full'
        ).execute()
    except HttpError as e:
        print(f"  Error fetching message {message_id}: {e}")
        return []

    headers = {h['name']: h['value'] for h in msg.get('payload', {}).get('headers', [])}
    msg_meta = {
        'subject': headers.get('Subject', '(no subject)')[:60],
        'from': headers.get('From', '(unknown)')[:40],
        'date': headers.get('Date', '(unknown date)')[:25],
    }

    attachments = []

    def walk_parts(parts):
        for part in parts:
            filename = part.get('filename')
            body = part.get('body', {})
            if filename:
                att = {
                    'filename': sanitize_filename(filename),
                    'size': body.get('size', 0),
                    'attachment_id': body.get('attachmentId'),
                    'data': body.get('data'),
                    'message_id': message_id,
                    'meta': msg_meta,
                }
                attachments.append(att)
            if 'parts' in part:
                walk_parts(part['parts'])

    payload = msg.get('payload', {})
    if 'parts' in payload:
        walk_parts(payload['parts'])
    elif payload.get('filename'):
        body = payload.get('body', {})
        attachments.append({
            'filename': sanitize_filename(payload['filename']),
            'size': body.get('size', 0),
            'attachment_id': body.get('attachmentId'),
            'data': body.get('data'),
            'message_id': message_id,
            'meta': msg_meta,
        })

    return attachments


def download_attachments(service, messages, output_dir, dry_run=False):
    """Scan messages for attachments and download them."""
    total_messages = len(messages)
    all_attachments = []

    print(f"\nScanning {total_messages} messages for attachments...")

    for i, msg in enumerate(messages):
        atts = get_message_attachments(service, msg['id'])
        all_attachments.extend(atts)
        if (i + 1) % 25 == 0:
            print(f"  Scanned {i + 1}/{total_messages} messages, found {len(all_attachments)} attachments...")

    if not all_attachments:
        print("\nNo attachments found.")
        return 0

    total_size = sum(a['size'] for a in all_attachments)
    print(f"\nFound {len(all_attachments)} attachments ({format_size(total_size)}) across {total_messages} messages.")

    if dry_run:
        print(f"\n[DRY RUN] Would download {len(all_attachments)} attachments to {output_dir}")
        for att in all_attachments[:20]:
            print(f"  {att['filename']} ({format_size(att['size'])}) — from: {att['meta']['from']}")
        if len(all_attachments) > 20:
            print(f"  ... and {len(all_attachments) - 20} more")
        return 0

    os.makedirs(output_dir, exist_ok=True)
    downloaded = 0

    print(f"\nDownloading to {output_dir}...")

    for i, att in enumerate(all_attachments):
        try:
            if att['attachment_id']:
                result = service.users().messages().attachments().get(
                    userId='me', messageId=att['message_id'], id=att['attachment_id']
                ).execute()
                file_data = base64.urlsafe_b64decode(result['data'])
            elif att['data']:
                file_data = base64.urlsafe_b64decode(att['data'])
            else:
                print(f"  Skipping {att['filename']}: no data available")
                continue

            path = get_unique_path(output_dir, att['filename'])
            with open(path, 'wb') as f:
                f.write(file_data)
            downloaded += 1

            if downloaded % 10 == 0:
                print(f"  Downloaded {downloaded}/{len(all_attachments)} attachments...")

        except Exception as e:
            print(f"  Error downloading {att['filename']}: {e}")

    print(f"\nDone! Downloaded {downloaded} attachments to {output_dir}")
    return downloaded


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
  %(prog)s --labels
  %(prog)s --get-label "promotions"
  %(prog)s --get-label "INBOX" --max 5 --preview 5

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
    parser.add_argument('--labels', action='store_true', help='List all Gmail labels')
    parser.add_argument('--get-label', metavar='LABEL', help='View messages under a label')
    parser.add_argument('--dry-run', '-n', action='store_true', help='Preview only, no deletion')
    parser.add_argument('--delete', '-d', action='store_true', help='Permanently delete messages')
    parser.add_argument('--trash', '-t', action='store_true', help='Move messages to trash (recoverable)')
    parser.add_argument('--label', '-l', metavar='LABEL', help='Apply label and archive (remove from inbox)')
    parser.add_argument('--download', action='store_true', help='Download attachments from matching messages')
    parser.add_argument('--output', '-o', default='./gmail-downloads', help='Output directory for downloads (default: ./gmail-downloads)')
    parser.add_argument('--no-confirm', '-y', action='store_true', help='Skip confirmation prompt')
    parser.add_argument('--max', '-m', type=int, default=500, help='Maximum messages to process (default: 500)')
    parser.add_argument('--preview', '-p', type=int, default=10, help='Number of messages to preview (default: 10)')
    
    args = parser.parse_args()

    # Handle standalone commands (no --query required)
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

    if args.labels:
        try:
            service = get_gmail_service()
            list_labels(service)
        except HttpError as e:
            print(f"Gmail API error: {e}")
            sys.exit(1)
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(1)
        sys.exit(0)

    if args.get_label:
        try:
            service = get_gmail_service()
            messages = get_messages_by_label(service, args.get_label, args.max)
            if not messages:
                if messages is not None:
                    print(f"\nNo messages found under label '{args.get_label}'.")
                sys.exit(0)
            preview_messages(service, messages, args.preview)
            print(f"\n{len(messages)} messages total under '{args.get_label}'.")
        except HttpError as e:
            print(f"Gmail API error: {e}")
            sys.exit(1)
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(1)
        sys.exit(0)

    if not args.query:
        print("Error: --query is required (or use --tidy, --labels, --get-label)")
        sys.exit(1)

    if not args.dry_run and not args.delete and not args.trash and not args.label and not args.download:
        print("Error: Specify --dry-run, --delete, --trash, --label <name>, or --download")
        sys.exit(1)

    action_count = sum([args.delete, args.trash, bool(args.label), args.download])
    if action_count > 1:
        print("Error: Cannot use multiple actions (--delete, --trash, --label, --download)")
        sys.exit(1)
    
    try:
        service = get_gmail_service()
        messages = search_messages(service, args.query, args.max)
        
        if not messages:
            print("\nNo messages found matching your query.")
            sys.exit(0)

        if args.download:
            download_attachments(service, messages, args.output, args.dry_run)
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
