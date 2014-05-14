#!/bin/python
import string
import sys
import re
import os

if( len(sys.argv) != 3 ):
	print "Usage: morph.py <flat-database> <file>"
	sys.exit(0)


database = sys.argv[1]
#print database
database_lines = open(database).readlines()
input_file = sys.argv[2]
#print input_file
input_lines = open(input_file).readlines()

verb2morph = {}
for entry in database_lines:
	a_tuple = string.split(string.strip(entry))
	verb2morph[a_tuple[0]] = a_tuple[1]

	
for line in input_lines:
	line = string.strip(line)

	if( verb2morph.has_key(line) ):
		print verb2morph[line]
	else:
		print line

	
	

