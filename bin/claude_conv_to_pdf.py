#!/usr/bin/env python3
"""
Claude Conversation Converter

A general-purpose script to convert exported Claude conversations to formatted 
PDFs or Markdown. Handles the messy text format from Claude's web interface 
copy/paste exports.

Usage:
    claude-conv input.txt                      # outputs input_conversation.pdf
    claude-conv input.txt output.pdf           # explicit PDF output
    claude-conv input.txt output.md            # markdown output  
    claude-conv input.txt -f md                # markdown with auto filename
    claude-conv input.txt -f pdf -t "Title"   # PDF with custom title
    
Output format is determined by file extension or -f/--format flag.
"""

import re
import sys
import os
import argparse
from datetime import datetime


def fix_encoding(text):
    """Fix common encoding issues from copy/paste."""
    replacements = {
        # Mojibake from UTF-8 interpreted as Latin-1
        '\xe2\x80\x94': '-',      # em dash
        '\xe2\x80\x99': "'",      # right single quote
        '\xe2\x80\x9c': '"',      # left double quote
        '\xe2\x80\x9d': '"',      # right double quote
        '\xe2\x86\x92': '->',     # arrow
        '\xc3\x97': 'x',          # multiplication sign
        '\xe2\x9c\x85': '[YES]',  # check mark
        '\xe2\x9d\x8c': '[NO]',   # x mark
        '\xe2\x80\xa2': '*',      # bullet
        # Direct unicode characters
        '\u2014': '-',            # em dash
        '\u2019': "'",            # right single quote
        '\u201c': '"',            # left double quote
        '\u201d': '"',            # right double quote
        '\u2192': '->',           # arrow
        '\u00d7': 'x',            # multiplication sign
        '\u2713': '[YES]',        # check mark
        '\u2717': '[NO]',         # x mark
        '\u2022': '*',            # bullet
        '\u2018': "'",            # left single quote
        '\u2026': '...',          # ellipsis
        '\u00a0': ' ',            # non-breaking space
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def is_timestamp(line):
    """Check if a line is a timestamp like '3:33 AM' or '10:45 PM'."""
    pattern = r'^\d{1,2}:\d{2}\s*[AaPp][Mm]$'
    return bool(re.match(pattern, line.strip()))


def is_metadata_noise(line):
    """Check if a line is Claude UI metadata noise to be filtered out."""
    line = line.strip()
    
    if not line:
        return True
    
    noise_patterns = [
        r'^\d+\s*steps?$',
        r'^\d+\s*results?$',
        r'^\d+s$',
        r'^Evaluated\s+',
        r'^Identified\s+',
        r'^Recognized\s+',
        r'^Analyzed\s+',
        r'^Processed\s+',
        r'^Generated\s+',
        r'^Created\s+',
        r'^Searched\s+',
        r'^Found\s+',
        r'^Retrieved\s+',
        r'^Completed\s+',
        r'^Thinking\s*',
        r'^Loading\s*',
        r'^Chat$',
        r'^Code$',
    ]
    
    for pattern in noise_patterns:
        if re.match(pattern, line, re.IGNORECASE):
            return True
    
    return False


def parse_conversation(text):
    """
    Parse a Claude conversation export into structured exchanges.
    Returns a list of dicts with 'user', 'timestamp', and 'claude' keys.
    """
    text = fix_encoding(text)
    lines = text.split('\n')
    
    exchanges = []
    current_exchange = {}
    current_section = None
    buffer = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        if is_timestamp(line):
            user_text = '\n'.join(buffer).strip()
            if user_text and not all(is_metadata_noise(l) for l in buffer):
                user_lines = [l for l in buffer if not is_metadata_noise(l)]
                user_text = '\n'.join(user_lines).strip()
                
                if user_text:
                    current_exchange['user'] = user_text
                    current_exchange['timestamp'] = line.strip()
                    current_section = 'claude'
                    buffer = []
            else:
                buffer = []
            
            i += 1
            continue
        
        if current_section == 'claude':
            lookahead_limit = 5
            found_timestamp_ahead = False
            
            for j in range(i + 1, min(i + lookahead_limit + 1, len(lines))):
                if is_timestamp(lines[j]):
                    between_lines = lines[i:j]
                    non_noise = [l for l in between_lines if not is_metadata_noise(l)]
                    if len(non_noise) <= 2:
                        found_timestamp_ahead = True
                        break
            
            if found_timestamp_ahead and not is_metadata_noise(line) and buffer:
                claude_lines = [l for l in buffer if not is_metadata_noise(l)]
                claude_text = '\n'.join(claude_lines).strip()
                
                if claude_text and 'user' in current_exchange:
                    current_exchange['claude'] = claude_text
                    exchanges.append(current_exchange)
                
                current_exchange = {}
                current_section = 'user'
                buffer = [line]
            else:
                buffer.append(line)
        else:
            buffer.append(line)
        
        i += 1
    
    if buffer and current_section == 'claude':
        claude_lines = [l for l in buffer if not is_metadata_noise(l)]
        claude_text = '\n'.join(claude_lines).strip()
        
        if claude_text and 'user' in current_exchange:
            current_exchange['claude'] = claude_text
            exchanges.append(current_exchange)
    
    return exchanges


# =============================================================================
# Markdown Output
# =============================================================================

def create_markdown(exchanges, output_file, title=None):
    """Generate a formatted Markdown file from parsed conversation exchanges."""
    
    if not title:
        title = "Claude Conversation"
    
    lines = []
    
    # Header
    lines.append(f"# {title}")
    lines.append("")
    lines.append(f"*Exported: {datetime.now().strftime('%Y-%m-%d %H:%M')}*")
    lines.append("")
    lines.append("---")
    lines.append("")
    
    # Each exchange
    for i, exchange in enumerate(exchanges):
        # User message
        lines.append("## You")
        lines.append("")
        lines.append(exchange.get('user', ''))
        lines.append("")
        
        if 'timestamp' in exchange:
            lines.append(f"*{exchange['timestamp']}*")
            lines.append("")
        
        # Claude response
        lines.append("## Claude")
        lines.append("")
        lines.append(exchange.get('claude', ''))
        lines.append("")
        
        # Separator
        if i < len(exchanges) - 1:
            lines.append("---")
            lines.append("")
    
    # Write file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    
    return output_file


# =============================================================================
# PDF Output
# =============================================================================

def escape_xml(text):
    """Escape special characters for ReportLab XML."""
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    return text


def format_text_for_pdf(text):
    """Convert plain text to ReportLab-safe formatted text."""
    text = escape_xml(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'\*(.+?)\*', r'<i>\1</i>', text)
    text = re.sub(r'`(.+?)`', r'<font face="Courier" size="9">\1</font>', text)
    return text


def create_pdf(exchanges, output_file, title=None):
    """Generate a formatted PDF from parsed conversation exchanges."""
    
    # Import PDF libraries only when needed
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.colors import HexColor
        from reportlab.lib.units import inch
    except ImportError:
        print("Error: reportlab is required for PDF output.")
        print("Install it with: pip install reportlab")
        sys.exit(1)
    
    if not title:
        title = "Claude Conversation"
    
    doc = SimpleDocTemplate(
        output_file,
        pagesize=letter,
        rightMargin=0.75*inch,
        leftMargin=0.75*inch,
        topMargin=0.75*inch,
        bottomMargin=0.75*inch
    )
    
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'CustomTitle', parent=styles['Title'],
        fontSize=16, spaceAfter=6, textColor=HexColor('#1a1a2e')
    )
    
    subtitle_style = ParagraphStyle(
        'Subtitle', parent=styles['Normal'],
        fontSize=10, spaceAfter=20, textColor=HexColor('#666666')
    )
    
    user_label_style = ParagraphStyle(
        'UserLabel', parent=styles['Normal'],
        fontSize=11, spaceBefore=12, spaceAfter=4,
        fontName='Helvetica-Bold', textColor=HexColor('#2d3436')
    )
    
    user_message_style = ParagraphStyle(
        'UserMessage', parent=styles['Normal'],
        fontSize=10, leading=14, spaceAfter=4, leftIndent=10,
        textColor=HexColor('#333333'), backColor=HexColor('#f5f5f5')
    )
    
    timestamp_style = ParagraphStyle(
        'Timestamp', parent=styles['Normal'],
        fontSize=8, textColor=HexColor('#888888'),
        leftIndent=10, spaceBefore=2, spaceAfter=8
    )
    
    claude_label_style = ParagraphStyle(
        'ClaudeLabel', parent=styles['Normal'],
        fontSize=11, spaceBefore=8, spaceAfter=4,
        fontName='Helvetica-Bold', textColor=HexColor('#6b4c9a')
    )
    
    claude_message_style = ParagraphStyle(
        'ClaudeMessage', parent=styles['Normal'],
        fontSize=10, leading=14, spaceAfter=4, leftIndent=10,
        textColor=HexColor('#444444')
    )
    
    code_style = ParagraphStyle(
        'CodeBlock', parent=styles['Normal'],
        fontSize=9, leading=12, leftIndent=20, fontName='Courier',
        backColor=HexColor('#f4f4f4'), spaceBefore=4, spaceAfter=4
    )
    
    story = []
    
    story.append(Paragraph(escape_xml(title), title_style))
    story.append(Paragraph(f"Exported: {datetime.now().strftime('%Y-%m-%d %H:%M')}", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1, color=HexColor('#cccccc')))
    story.append(Spacer(1, 15))
    
    for i, exchange in enumerate(exchanges):
        story.append(Paragraph("You:", user_label_style))
        
        user_text = format_text_for_pdf(exchange.get('user', ''))
        for para in user_text.split('\n'):
            if para.strip():
                story.append(Paragraph(para, user_message_style))
        
        if 'timestamp' in exchange:
            story.append(Paragraph(exchange['timestamp'], timestamp_style))
        
        story.append(Paragraph("Claude:", claude_label_style))
        
        claude_text = exchange.get('claude', '')
        paragraphs = claude_text.split('\n\n')
        
        for para in paragraphs:
            if not para.strip():
                continue
            
            if para.strip().startswith('```') or (para.strip().startswith('bash') and len(para.strip().split('\n')[0]) < 20):
                code_content = para.strip()
                if code_content.startswith('```'):
                    code_content = re.sub(r'^```\w*\n?', '', code_content)
                    code_content = re.sub(r'\n?```$', '', code_content)
                story.append(Paragraph(escape_xml(code_content), code_style))
            else:
                formatted = format_text_for_pdf(para.replace('\n', ' '))
                story.append(Paragraph(formatted, claude_message_style))
        
        if i < len(exchanges) - 1:
            story.append(Spacer(1, 10))
            story.append(HRFlowable(width="100%", thickness=0.5, color=HexColor('#e0e0e0')))
            story.append(Spacer(1, 5))
    
    doc.build(story)
    return output_file


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Convert Claude conversation exports to PDF or Markdown.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s conversation.txt                    # Auto-detect, default PDF
  %(prog)s conversation.txt output.md          # Markdown output
  %(prog)s conversation.txt -f md              # Markdown with auto filename
  %(prog)s conversation.txt -f pdf -t "Chat"   # PDF with custom title
        """
    )
    
    parser.add_argument('input', help='Input text file (Claude conversation export)')
    parser.add_argument('output', nargs='?', help='Output file (extension determines format)')
    parser.add_argument('-f', '--format', choices=['pdf', 'md', 'markdown'],
                        help='Output format (overrides extension detection)')
    parser.add_argument('-t', '--title', help='Document title')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found.")
        sys.exit(1)
    
    # Determine output format and filename
    base = os.path.splitext(args.input)[0]
    
    if args.format:
        fmt = 'md' if args.format in ('md', 'markdown') else 'pdf'
        if args.output:
            output_file = args.output
        else:
            output_file = f"{base}_conversation.{fmt}"
    elif args.output:
        ext = os.path.splitext(args.output)[1].lower()
        fmt = 'md' if ext in ('.md', '.markdown') else 'pdf'
        output_file = args.output
    else:
        fmt = 'pdf'
        output_file = f"{base}_conversation.pdf"
    
    # Read and parse
    with open(args.input, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    
    print(f"Parsing conversation from: {args.input}")
    exchanges = parse_conversation(content)
    
    if not exchanges:
        print("Warning: No conversation exchanges found. The file format may not be recognized.")
        sys.exit(1)
    
    print(f"Found {len(exchanges)} exchanges")
    
    # Generate output
    if fmt == 'md':
        create_markdown(exchanges, output_file, args.title)
        print(f"Markdown created: {output_file}")
    else:
        create_pdf(exchanges, output_file, args.title)
        print(f"PDF created: {output_file}")


if __name__ == "__main__":
    main()
