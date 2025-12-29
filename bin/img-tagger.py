#!/usr/bin/env python3
"""
img-tagger - AI-powered image tagging and organization
Compatible with macOS and Linux
Requires: ollama with a vision model (llava, llama3.2-vision)

Setup (macOS):
    brew install ollama
    ollama serve &
    ollama pull llava

Usage:
    img-tagger.py <path> [options]
    img-tagger.py ./photos --organize --categories "people,pets,nature,food,travel"
"""

import argparse
import json
import os
import subprocess
import sys
import shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Image extensions to process
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.heic'}

def check_ollama():
    """Check if ollama is installed and running."""
    try:
        result = subprocess.run(['ollama', 'list'], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

def analyze_image(image_path: str, model: str, prompt: str) -> dict:
    """Analyze a single image with ollama."""
    try:
        result = subprocess.run(
            ['ollama', 'run', model, prompt, image_path],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            return {
                'file': str(image_path),
                'tags': result.stdout.strip(),
                'error': None
            }
        else:
            return {
                'file': str(image_path),
                'tags': None,
                'error': result.stderr.strip()
            }
    except subprocess.TimeoutExpired:
        return {
            'file': str(image_path),
            'tags': None,
            'error': 'Timeout'
        }
    except Exception as e:
        return {
            'file': str(image_path),
            'tags': None,
            'error': str(e)
        }

def categorize_image(image_path: str, model: str, categories: list) -> dict:
    """Categorize an image into predefined categories."""
    categories_str = ', '.join(categories)
    prompt = f"""Look at this image and categorize it. 
Choose the BEST matching category from this list: {categories_str}
Also provide a confidence score (high/medium/low).
Respond in this exact format:
category: <chosen category>
confidence: <high/medium/low>
description: <brief 5-10 word description>"""
    
    try:
        result = subprocess.run(
            ['ollama', 'run', model, prompt, image_path],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            output = result.stdout.strip()
            # Parse the response
            category = None
            confidence = None
            description = None
            
            for line in output.split('\n'):
                line = line.strip().lower()
                if line.startswith('category:'):
                    category = line.split(':', 1)[1].strip()
                elif line.startswith('confidence:'):
                    confidence = line.split(':', 1)[1].strip()
                elif line.startswith('description:'):
                    description = line.split(':', 1)[1].strip()
            
            # Validate category
            if category:
                # Find best match from allowed categories
                category_lower = category.lower()
                for cat in categories:
                    if cat.lower() in category_lower or category_lower in cat.lower():
                        category = cat
                        break
                else:
                    category = 'other'
            else:
                category = 'other'
            
            return {
                'file': str(image_path),
                'category': category,
                'confidence': confidence or 'unknown',
                'description': description or '',
                'raw': output,
                'error': None
            }
        else:
            return {
                'file': str(image_path),
                'category': 'error',
                'confidence': None,
                'description': None,
                'error': result.stderr.strip()
            }
    except Exception as e:
        return {
            'file': str(image_path),
            'category': 'error',
            'confidence': None,
            'description': None,
            'error': str(e)
        }

def get_images(path: Path, recursive: bool = False) -> list:
    """Get all image files from a path."""
    images = []
    
    if path.is_file():
        if path.suffix.lower() in IMAGE_EXTENSIONS:
            images.append(path)
    elif path.is_dir():
        if recursive:
            for ext in IMAGE_EXTENSIONS:
                images.extend(path.rglob(f'*{ext}'))
                images.extend(path.rglob(f'*{ext.upper()}'))
        else:
            for ext in IMAGE_EXTENSIONS:
                images.extend(path.glob(f'*{ext}'))
                images.extend(path.glob(f'*{ext.upper()}'))
    
    return sorted(set(images))

def organize_files(results: list, output_dir: Path, copy: bool = True):
    """Organize files into category folders."""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for result in results:
        if result.get('error'):
            continue
        
        category = result.get('category', 'other')
        source = Path(result['file'])
        
        # Create category folder
        cat_dir = output_dir / category
        cat_dir.mkdir(exist_ok=True)
        
        dest = cat_dir / source.name
        
        # Handle duplicates
        counter = 1
        while dest.exists():
            stem = source.stem
            suffix = source.suffix
            dest = cat_dir / f"{stem}_{counter}{suffix}"
            counter += 1
        
        if copy:
            shutil.copy2(source, dest)
        else:
            shutil.move(source, dest)
        
        print(f"  {source.name} -> {category}/")

def main():
    parser = argparse.ArgumentParser(
        description='AI-powered image tagging and organization',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s photo.jpg                          # Tag single image
    %(prog)s ./photos -r                        # Tag recursively
    %(prog)s ./photos -o tags.json              # Save as JSON
    %(prog)s ./photos --organize                # Organize into folders
    %(prog)s ./photos --organize --categories "family,pets,travel,food,nature"
        """
    )
    
    parser.add_argument('path', help='Image file or directory')
    parser.add_argument('-m', '--model', default='llava',
                        help='Ollama model (default: llava)')
    parser.add_argument('-r', '--recursive', action='store_true',
                        help='Process directories recursively')
    parser.add_argument('-o', '--output', help='Output file (JSON format)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Verbose output')
    parser.add_argument('-j', '--jobs', type=int, default=1,
                        help='Parallel jobs (default: 1)')
    
    # Organization options
    parser.add_argument('--organize', action='store_true',
                        help='Organize images into category folders')
    parser.add_argument('--organize-dir', default='./organized',
                        help='Output directory for organized files')
    parser.add_argument('--move', action='store_true',
                        help='Move files instead of copying when organizing')
    parser.add_argument('--categories',
                        default='people,pets,nature,food,travel,events,screenshots,documents,other',
                        help='Comma-separated list of categories')
    
    args = parser.parse_args()
    
    # Check ollama
    if not check_ollama():
        print("Error: ollama is not installed or not running", file=sys.stderr)
        print("\nInstall on macOS:", file=sys.stderr)
        print("  brew install ollama", file=sys.stderr)
        print("\nOr download from: https://ollama.ai", file=sys.stderr)
        print("\nThen start the service and pull a model:", file=sys.stderr)
        print("  ollama serve &", file=sys.stderr)
        print("  ollama pull llava", file=sys.stderr)
        sys.exit(1)
    
    # Get images
    path = Path(args.path)
    if not path.exists():
        print(f"Error: Path not found: {path}", file=sys.stderr)
        sys.exit(1)
    
    images = get_images(path, args.recursive)
    
    if not images:
        print(f"No images found in {path}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(images)} images")
    
    # Parse categories
    categories = [c.strip() for c in args.categories.split(',')]
    
    # Process images
    results = []
    
    if args.organize:
        # Categorization mode
        prompt_fn = lambda img: categorize_image(str(img), args.model, categories)
    else:
        # Tagging mode
        prompt = "Analyze this image and list what you see as comma-separated tags. Include: people (count), animals (type), objects, location/setting, activities. Be concise - just tags, no sentences."
        prompt_fn = lambda img: analyze_image(str(img), args.model, prompt)
    
    if args.jobs > 1:
        with ThreadPoolExecutor(max_workers=args.jobs) as executor:
            futures = {executor.submit(prompt_fn, img): img for img in images}
            for i, future in enumerate(as_completed(futures), 1):
                result = future.result()
                results.append(result)
                if args.verbose:
                    print(f"[{i}/{len(images)}] {result['file']}")
                    if result.get('tags'):
                        print(f"  {result['tags']}")
                    elif result.get('category'):
                        print(f"  -> {result['category']}")
    else:
        for i, img in enumerate(images, 1):
            result = prompt_fn(img)
            results.append(result)
            if args.verbose or not args.output:
                print(f"[{i}/{len(images)}] {result['file']}")
                if result.get('error'):
                    print(f"  Error: {result['error']}")
                elif result.get('tags'):
                    print(f"  {result['tags']}")
                elif result.get('category'):
                    print(f"  -> {result['category']} ({result.get('confidence', '?')})")
                    if result.get('description'):
                        print(f"     {result['description']}")
            print()
    
    # Organize files if requested
    if args.organize:
        print(f"\nOrganizing into {args.organize_dir}...")
        organize_files(results, Path(args.organize_dir), copy=not args.move)
    
    # Save results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to {args.output}")
    
    # Summary
    if args.organize:
        from collections import Counter
        cats = Counter(r.get('category', 'error') for r in results)
        print("\nSummary:")
        for cat, count in cats.most_common():
            print(f"  {cat}: {count}")

if __name__ == '__main__':
    main()
