from flask import Flask, jsonify, request, abort
import json
import os
import requests
from apscheduler.schedulers.background import BackgroundScheduler
import argparse
from flask_cors import CORS
import re

app = Flask(__name__)
CORS(app)

EN_FILE = 'enumbers.json'

USER_AGENT = "ENumbersApp/1.0 (contact@example.com)"

# Parse command-line argument for editing
parser = argparse.ArgumentParser()
parser.add_argument('--allow-editing', action='store_true', help='Allow editing (POST, PUT, DELETE) endpoints')
args, unknown = parser.parse_known_args()
EDITING_ALLOWED = args.allow_editing

def check_editing_allowed():
    if not EDITING_ALLOWED:
        return jsonify({'error': 'Editing is disabled on this server.'}), 403

def load_enumbers():
    with open(EN_FILE, encoding='utf-8') as f:
        return json.load(f)

def save_enumbers(data):
    # Remove spaces from the 'code' field for every entry before saving
    for entry in data:
        if 'code' in entry:
            entry['code'] = entry['code'].replace(' ', '')
    with open(EN_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# Helper function to fetch Open Food Facts data for a barcode
def fetch_openfoodfacts_product(barcode):
    url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
    headers = {"User-Agent": USER_AGENT}
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return data.get("product")
    except Exception as e:
        print(f"Error fetching {barcode}: {e}")
    return None

# Helper function to fetch all additives (E numbers) from Open Food Facts

def fetch_all_additives():
    url = "https://world.openfoodfacts.org/facets/additives.json"
    headers = {"User-Agent": USER_AGENT}
    try:
        response = requests.get(url, headers=headers, timeout=20)
        if response.status_code == 200:
            data = response.json()
            return data.get("tags", [])
    except Exception as e:
        print(f"Error fetching additives: {e}")
    return []

# Helper function to update enumbers.json with the latest E-number (additive) data from Open Food Facts

def update_enumbers_from_off_additives_logic():
    global enumbers
    additives = fetch_all_additives()
    if not additives:
        print('Failed to fetch additives from Open Food Facts')
        return 0

    def normalize_code(code):
        # Extract E-number using regex, remove spaces/dashes, uppercase
        match = re.match(r'(E\d+)', code.replace(' ', '').replace('-', '').upper())
        return match.group(1) if match else code.replace(' ', '').replace('-', '').upper()

    # Build a dict for quick lookup by normalized E number code (e.g., E330, E322, etc.)
    additive_dict = {}
    for add in additives:
        if 'name' in add and add['name'].startswith('E'):
            # Extract E-number using regex from the additive name
            match = re.match(r'(E\d+)', add['name'].replace(' ', '').replace('-', '').upper())
            if match:
                code = match.group(1)
                additive_dict[code] = add

    # Build a set of all local codes for quick lookup
    local_codes = set(normalize_code(entry.get('code', '')) for entry in enumbers)
    updated = 0
    code_to_entry = {normalize_code(entry.get('code', '')): entry for entry in enumbers}

    # 1. Update existing entries and mark as removed if not present in Open Food Facts
    for entry in enumbers:
        entry_code = normalize_code(entry.get('code', ''))
        if entry_code in additive_dict:
            add = additive_dict[entry_code]
            # Prepare the openfoodfacts_additive field with links
            off_add = {
                'name': add.get('name'),
                'url': add.get('url'),
                'sameAs': add.get('sameAs', [])
            }
            entry['openfoodfacts_additive'] = off_add
            # Remove 'removed' flag if present
            if 'removed' in entry:
                entry.pop('removed')
            updated += 1
        else:
            # Mark as removed, but do not delete
            entry['removed'] = True
            entry.pop('openfoodfacts_additive', None)

    # 2. Add new E numbers from Open Food Facts if not present locally
    for code, add in additive_dict.items():
        if code not in code_to_entry:
            new_entry = {
                'code': code,
                'name': add.get('name', code),
                'openfoodfacts_additive': {
                    'name': add.get('name'),
                    'url': add.get('url'),
                    'sameAs': add.get('sameAs', [])
                }
            }
            enumbers.append(new_entry)
            updated += 1

    save_enumbers(enumbers)
    enumbers = load_enumbers()
    print(f'Updated {updated} entries with Open Food Facts additive data (including new and removed).')
    return updated

# Endpoint to update enumbers.json with Open Food Facts data
@app.route('/api/update_openfoodfacts', methods=['POST'])
def update_openfoodfacts():
    global enumbers
    updated = 0
    for entry in enumbers:
        barcode = entry.get('code')
        if barcode:
            product = fetch_openfoodfacts_product(barcode)
            if product:
                entry['openfoodfacts'] = product
                updated += 1
    save_enumbers(enumbers)
    return jsonify({'message': f'Updated {updated} entries with Open Food Facts data.'})

# Flask route for manual update
@app.route('/api/update_enumbers_from_off_additives', methods=['POST'])
def update_enumbers_from_off_additives():
    denied = check_editing_allowed()
    if denied:
        return denied
    global enumbers
    updated = update_enumbers_from_off_additives_logic()
    if updated == 0:
        return jsonify({'error': 'Failed to fetch additives from Open Food Facts'}), 500
    return jsonify({'message': f'Updated {updated} entries with Open Food Facts additive data.'})

# Schedule daily update using APScheduler
scheduler = BackgroundScheduler()
scheduler.add_job(update_enumbers_from_off_additives_logic, 'interval', days=1)
scheduler.start()

enumbers = load_enumbers()

@app.route('/api/enumbers', methods=['GET'])
def get_enumbers():
    global enumbers
    query = request.args.get('q', '').lower()
    if query:
        filtered = [e for e in enumbers if query in e['code'].lower() or query in e['name'].lower()]
        return jsonify(filtered)
    return jsonify(enumbers)

@app.route('/api/enumbers', methods=['POST'])
def create_enumber():
    denied = check_editing_allowed()
    if denied:
        return denied
    global enumbers
    data = request.get_json()
    if not data or 'code' not in data or 'name' not in data:
        return jsonify({'error': 'Missing code or name'}), 400
    if any(e['code'] == data['code'] for e in enumbers):
        return jsonify({'error': 'E-number already exists'}), 409
    enumbers.append({'code': data['code'], 'name': data['name']})
    save_enumbers(enumbers)
    return jsonify({'message': 'Created', 'enumber': data}), 201

@app.route('/api/enumbers/<code>', methods=['PUT'])
def update_enumber(code):
    denied = check_editing_allowed()
    if denied:
        return denied
    global enumbers
    data = request.get_json()
    if not data or 'name' not in data:
        return jsonify({'error': 'Missing name'}), 400
    for e in enumbers:
        if e['code'] == code:
            e['name'] = data['name']
            save_enumbers(enumbers)
            return jsonify({'message': 'Updated', 'enumber': e})
    return jsonify({'error': 'E-number not found'}), 404

@app.route('/api/enumbers/<code>', methods=['DELETE'])
def delete_enumber(code):
    denied = check_editing_allowed()
    if denied:
        return denied
    global enumbers
    for i, e in enumerate(enumbers):
        if e['code'] == code:
            removed = enumbers.pop(i)
            save_enumbers(enumbers)
            return jsonify({'message': 'Deleted', 'enumber': removed})
    return jsonify({'error': 'E-number not found'}), 404

if __name__ == '__main__':
    app.run(debug=True) 