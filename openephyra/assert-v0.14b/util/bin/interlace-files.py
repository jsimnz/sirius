#!/bin/python
import sys
import string

if (len(sys.argv) == 1):
	print "Usage: interlace-files.py <file1> <file2> ... <filen>"
	sys.exit(1)

files_lines = []

i=0
for i in range(1, len(sys.argv)-1):
	files_lines.append(open(sys.argv[i]).readlines())


outfile = open(sys.argv[len(sys.argv)-1], "w")
outfile_lines = []

i=0
j=0
for i in range(0, len(files_lines[0])):
	for j in range(0, len(files_lines)):
		outfile_lines.append(files_lines[j][i])
	outfile_lines.append("\n")

outfile.writelines(outfile_lines)

	
