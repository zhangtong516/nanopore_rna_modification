process GENERATE_REPORT {
    tag "Generating final report"
    
    storeDir "${params.output_dir}/reports"
    
    input:
    tuple val(samplename), path(summary), path(polya_summary), path(mod_summary), path(alignment_stats)

    output:
    path "${samplename}_final_report.html", emit: report

    script:
    """
    cat > generate_report.py << 'EOF'
import os
from datetime import datetime

# Read input files
with open('${summary}', 'r') as f:
    seq_summary = f.read()

with open('${polya_summary}', 'r') as f:
    polya_summary = f.read()

with open('${alignment_stats}', 'r') as f:
    align_stats = f.read()

with open('${mod_summary}', 'r') as f:
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

with open('${samplename}_final_report.html', 'w') as f:
    f.write(html_content)
EOF

    python generate_report.py
    """
}