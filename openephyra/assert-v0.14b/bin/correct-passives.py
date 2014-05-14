#!/bin/python
import string
import sys
import re

if( len(sys.argv) == 1 ):
	print "Usage: correct-passives.py <passives-file> <data-file> <voice-feature-index> <passive-value> <active-value>"
	sys.exit(1)

passive_lines = open(sys.argv[1]).readlines()

if( sys.argv[2] == "-" ):
	data_file = sys.stdin
else:
	data_file = open(sys.argv[2])

voice_index = int(sys.argv[3])
passive_val = sys.argv[4]
active_val = sys.argv[5]

passive_hash = {}

for line in passive_lines:
	line = string.strip(line)
	print >>sys.stderr, "adding", line[5:], "..."
	passive_hash[line[5:]] = 1


data_line = data_file.readline()

while(data_line != "" ):
	if(len(string.strip(data_line)) == 0):
		print ""
		sys.stderr.write(".")

	else:
		line_list = string.split(data_line)

		if(passive_hash.has_key(line_list[0])):
			line_list[voice_index] = passive_val
		else:
			line_list[voice_index] = active_val

		print string.join(line_list)

	data_line = data_file.readline()
