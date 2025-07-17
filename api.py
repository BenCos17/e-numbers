from flask import Flask, jsonify, request, abort
import json
import os

app = Flask(__name__)

EN_FILE = 'enumbers.json'

def load_enumbers():
    with open(EN_FILE, encoding='utf-8') as f:
        return json.load(f)

def save_enumbers(data):
    with open(EN_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

enumbers = load_enumbers()

@app.route('/api/enumbers', methods=['GET'])
def get_enumbers():
    query = request.args.get('q', '').lower()
    if query:
        filtered = [e for e in enumbers if query in e['code'].lower() or query in e['name'].lower()]
        return jsonify(filtered)
    return jsonify(enumbers)

@app.route('/api/enumbers', methods=['POST'])
def create_enumber():
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
    global enumbers
    for i, e in enumerate(enumbers):
        if e['code'] == code:
            removed = enumbers.pop(i)
            save_enumbers(enumbers)
            return jsonify({'message': 'Deleted', 'enumber': removed})
    return jsonify({'error': 'E-number not found'}), 404

if __name__ == '__main__':
    app.run(debug=True) 