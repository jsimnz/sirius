#!/bin/python

import string
import sys
import re
import os


TRUE = 1
FALSE = 0

if( len(sys.argv) == 1 ):
	print "Usage: add-parent-phrase-and-head-as-feature.py <data-file>"
	print "FOR THIS SCRIPT TO WORK, THE NODES MUST BE ARRANGED IN ASCENDING ORDER OF NODE START-END INDICES"
	print "THE FIRST FOUR COLUMNS SHOULD BE STANDARD"
	sys.exit(1)

infile = open(sys.argv[1])

feature_vector_list = []
modified_feature_vector_list = []

a_feature_vector = infile.readline()

while ( a_feature_vector != "" ):
	if( a_feature_vector == "\012" ):
		modified_feature_vector_list = []
		
		#--- the entire examples is read in the feature_vector_list.  let's process it ---#
		for i in range(0, len(feature_vector_list)):

			target_index = int(string.split(feature_vector_list[i][1], "_")[0])
			start_index  = int(feature_vector_list[i][2])
			end_index = int(feature_vector_list[i][3])

			if( start_index <= target_index and end_index >= target_index ):
				continue

			#--- a copy of the feature vector list is necessary ---#
			some_list = [] + feature_vector_list[i]
			modified_feature_vector_list = modified_feature_vector_list + [some_list]

		#--- after processing, print the list of feature vectors to std output---#
		for list in modified_feature_vector_list:
			print string.join(list)
		print

		#sys.exit(1)
		#--- empty the feature vector list ---#
		feature_vector_list = []
		modified_feature_vector_list = []
		
	else:
		#--- if it is a legitimate feature vector (no blank line or end of file), then add it to the list of feature vectors ---#
		if( a_feature_vector != "" and a_feature_vector != "\012" ):
			a_feature_vector_list = string.split(a_feature_vector)
			feature_vector_list.append(a_feature_vector_list)

	a_feature_vector = infile.readline()

		


# a_feature_vector = infile.readline()

# while ( a_feature_vector != "" ):
# 	if( a_feature_vector == "\012" ):
# 		modified_feature_vector_list = []

# 		#--- the entire examples is read in the feature_vector_list.  let's process it ---#
# 		for i in range(0, len(feature_vector_list)):



# 			#--- a copy of the feature vector list is necessary ---#
# 			some_list = [] + feature_vector_list[j]
# 			modified_feature_vector_list = modified_feature_vector_list + [some_list]


# 			#--- the indices become 1, 2, 3, etc. because the length of the list dynamically increases ---#
# 			modified_feature_vector_list[-1][phrase_index:phrase_index] = [str(counter)]

# 		#--- after processing, print the list of feature vectors to std output---#
# 		for list in modified_feature_vector_list:
# 			print string.join(list)
# 		print

# 		sys.exit(1)
# 		#--- empty the feature vector list ---#
# 		feature_vector_list = []
# 		modified_feature_vector_list = []
		
# 	else:
# 		#--- if it is a legitimate feature vector (no blank line or end of file), then add it to the list of feature vectors ---#
# 		if( a_feature_vector != "" and a_feature_vector != "\012" ):
# 			a_feature_vector_list = string.split(a_feature_vector)
# 			feature_vector_list.append(a_feature_vector_list)

# 	a_feature_vector = infile.readline()

		
