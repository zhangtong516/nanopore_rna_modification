#!/usr/bin/env python3
import os
import sys
from datetime import datetime

def generate_html_report(samplename, summary_file, polya_summary_file, mod_summary_file, alignment_stats_file):
    """Generate HTML report from input files"""
    
    # Read input files
    with open(summary_file, 'r') as f:
        seq_summary = f.read()

    with open(polya_summary_file, 'r') as f:
        polya_summary = f.read()

    with open(alignment_stats_file, 'r') as f:
        align_stats = f.read()

    with open(mod_summary_file, 'r') as f:
        mod_summary = f.read()

    # Generate HTML report
    html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Nanopore RNA Modification Analysis Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
        .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
        pre {{ background-color: #f8f8f8; padding: 10px; border-radius: 3px; overflow-x: auto; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Nanopore RNA Modification Analysis Report</h1>
        <p>Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    </div>
    
    <div class="section">
        <h2>Sequencing Summary</h2>
        <pre>{seq_summary}</pre>
    </div>
    
    <div class="section">
        <h2>PolyA Tail Analysis</h2>
        <pre>{polya_summary}</pre>
    </div>
    
    <div class="section">
        <h2>Alignment Statistics</h2>
        <pre>{align_stats}</pre>
    </div>
    
    <div class="section">
        <h2>RNA Modifications</h2>
        <pre>{mod_summary}</pre>
    </div>
</body>
</html>
"""

    # Write HTML report
    output_file = f"{samplename}_final_report.html"
    with open(output_file, 'w') as f:
        f.write(html_content)
    
    print(f"Report generated: {output_file}")
    return output_file

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Usage: python generate_report.py <samplename> <summary_file> <polya_summary_file> <mod_summary_file> <alignment_stats_file>")
        sys.exit(1)
    
    samplename = sys.argv[1]
    summary_file = sys.argv[2]
    polya_summary_file = sys.argv[3]
    mod_summary_file = sys.argv[4]
    alignment_stats_file = sys.argv[5]
    
    generate_html_report(samplename, summary_file, polya_summary_file, mod_summary_file, alignment_stats_file)