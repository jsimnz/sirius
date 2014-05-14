#!/bin/python
import string
import sys
import re
import os

if( len(sys.argv) == 1 ):
	print "Usage: dup.py <file>"
	sys.exit(1)

file = open(sys.argv[1])

feature_hash = {}
line = file.readline()
while (line != ""):
	list = string.split(line, " ", 1)
	#print list

	if(feature_hash.has_key(list[1])):
		feature_hash[list[1]][0] = feature_hash[list[1]][0] + 1
		#feature_hash[list[1]] = 1
	else:
		feature_hash[list[1]] = []
		feature_hash[list[1]].append(1)
		feature_hash[list[1]].append(list[0])
	line = file.readline()

for key in feature_hash.keys():
	if( feature_hash[key][0] == 1 ):
		print "%s %s" % (feature_hash[key][1], string.strip(key))
	#else:
	#	print "found duplicate"

#print feature_hash
#sys.exit(1)
	

# #!/usr/bin/tclsh
# set name [lindex $argv 0]
# set fh_i [open $name]
# array set aline {}
# array set aclass {}
# while {[gets $fh_i line] > 0} {
#    set class [lindex $line 0]
#    set dline [lrange $line 1 end]
#    if {[info exists aline($dline)]} {
#         set dclass $aclass($dline) 
#         if {$class != $dclass} {
#         incr aline($dline)
#        } 
#    } else  {
#     set aline($dline) 1
#     set aclass($dline) $class
#    }
# }
# foreach line [array names aline] {
#   if {$aline($line) == 1} {
#    puts "$aclass($line) $line"
#   }
# }

