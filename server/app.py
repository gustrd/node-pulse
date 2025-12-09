from flask import Flask, render_template
import os
import time
from datetime import datetime
import config

app = Flask(__name__)

# Helper to format time
def format_time(timestamp):
    return datetime.fromtimestamp(timestamp).astimezone().strftime('%Y-%m-%d %H:%M:%S %z')

def get_nodes():
    nodes = []
    if not os.path.exists(config.STATUS_DIR):
        return nodes

    now = time.time()
    for filename in os.listdir(config.STATUS_DIR):
        if not filename.endswith('.txt'):
            continue
        
        filepath = os.path.join(config.STATUS_DIR, filename)
        try:
            mtime = os.path.getmtime(filepath)
            with open(filepath, 'r') as f:
                content = f.read()
            
            node_name = filename[:-4] # Remove .txt
            time_since_update = now - mtime
            
            status_class = "normal"
            if time_since_update > config.STALE_CRITICAL_SECONDS:
                status_class = "critical"
            elif time_since_update > config.STALE_WARNING_SECONDS:
                status_class = "warning"

            nodes.append({
                'name': node_name,
                'content': content,
                'last_updated': format_time(mtime),
                'seconds_ago': int(time_since_update),
                'status_class': status_class
            })
        except Exception as e:
            print(f"Error reading {filename}: {e}")
    
    # Sort by hostname
    return sorted(nodes, key=lambda x: x['name'])

@app.route('/')
def dashboard():
    nodes = get_nodes()
    return render_template('dashboard.html', nodes=nodes)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
