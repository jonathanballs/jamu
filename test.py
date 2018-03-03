#!/usr/bin/python3
# A quick script to test the json interface

import subprocess
import json

p = subprocess.Popen("./jamu --json".split(' '),
                   stdin=subprocess.PIPE,
                   stdout=subprocess.PIPE,
                   encoding='utf-8',
                   universal_newlines=True) #this is for text communication

NUM_STEPS = 100

hashes = []

for i in range(NUM_STEPS):
    p.stdin.write(json.dumps({ 'cmd': 'info', 'args': [] }) + '\n')
    p.stdin.flush()
    p.stdin.write(json.dumps({ 'cmd': 'step', 'args': [] }) + '\n')
    p.stdin.flush()
    hash = json.loads(p.stdout.readline())['machine_hash']
    hashes.append(hash)

for i in range(NUM_STEPS):
    p.stdin.write(json.dumps({ 'cmd': 'prev', 'args': [] }) + '\n')
    p.stdin.flush()
    p.stdin.write(json.dumps({ 'cmd': 'info', 'args': [] }) + '\n')
    p.stdin.flush()
    l = json.loads(p.stdout.readline())
    hash = l['machine_hash']

    if hash != hashes.pop():
        print("no match at ", l)

print("Complete")

