#!/bin/python

import string
import sys
import re
import os


TRUE = 1
FALSE = 0

if( len(sys.argv) == 1 ):
	print "Usage: add-parent-phrase-and-head-as-feature.py <data-file> <phrase-index> <headword-index> <headword-pos-index>"
	print "FOR THIS SCRIPT TO WORK, THE NODES MUST BE ARRANGED IN ASCENDING ORDER OF NODE START-END INDICES"
	sys.exit(1)
	
infile = open(sys.argv[1])
phrase_index = int(sys.argv[2])
headword_index = int(sys.argv[3])
headword_pos_index = int(sys.argv[4])

feature_vector_list = []
a_feature_vector = infile.readline()

modified_feature_vector_list = []

while ( a_feature_vector != "" ):
	if( a_feature_vector == "\012" ):
		modified_feature_vector_list = []
		#--- the entire examples is read in the feature_vector_list.  let's process it ---#
		for i in range(0, len(feature_vector_list)):

			found_parent_flag = FALSE

			for k in range(i+1, len(feature_vector_list)):
				#--- check if this can be parent.  if not, then break ---#
				if( int(feature_vector_list[k][2]) == int(feature_vector_list[i][2]) and int(feature_vector_list[k][3]) >= int(feature_vector_list[i][3]) ):
					found_parent_flag = TRUE
					parent_index = k
					break
				elif( (feature_vector_list[k][2]) != int(feature_vector_list[i][2]) ):
					break
						
			if( found_parent_flag == FALSE ):
				for j in range(i-1, 0, -1):
					#--- check one-by-one nodes before till you reach one that is equal to or greater than the end of the current node ---#
					if( int(feature_vector_list[j][3]) < int(feature_vector_list[i][3]) ):
						if( found_parent_flag == TRUE ):
							break
						continue

					if( int(feature_vector_list[j][3]) >= int(feature_vector_list[i][3]) ): #--- remember that start point of any node prior will be <= that of current as they are sorted ---#
						found_parent_flag = TRUE
						parent_index = j
						continue

			#--- here, the found_parent_flag should be set ---#
			#--- if the constituent's parent is not in the list of hypotheses ---#
			if( found_parent_flag == FALSE ):
				parent_phrase_type = "U"
				parent_phrase_headword = "U"
				parent_phrase_headword_pos = "U"
			else:
				parent_phrase_type = feature_vector_list[parent_index][phrase_index]
				parent_phrase_headword = feature_vector_list[parent_index][headword_index]
				parent_phrase_headword_pos = feature_vector_list[parent_index][headword_pos_index]

			#--- a copy of the feature vector list is necessary ---#
			some_list = [] + feature_vector_list[i]
			modified_feature_vector_list = modified_feature_vector_list + [some_list]

			#--- the indices become 1, 2, 3, etc. because the length of the list dynamically increases ---#
			modified_feature_vector_list[-1][phrase_index+1:phrase_index+1] = [parent_phrase_type]
			modified_feature_vector_list[-1][headword_index+2:headword_index+2] = [parent_phrase_headword]
			modified_feature_vector_list[-1][headword_pos_index+3:headword_pos_index+3] = [parent_phrase_headword_pos]
		
		#--- after processing, print the list of feature vectors to std output---#
		for list in modified_feature_vector_list:
			print string.join(list)
		print

#		#--- after processing, print the list of feature vectors to std output---#
#		for list in feature_vector_list:
#			print string.join(list)
#		print

		#sys.exit(1)
		#--- empty the feature vector list ---#
		feature_vector_list = []
		modified_feature_vector_list = []
		
	else:
		#--- if it is a legitimate feature vector (no blank line or end of file), then add it to the list of feature vectors ---#
		if( a_feature_vector != "" and a_feature_vector != "\012" ):
			feature_vector_list.append(string.split(a_feature_vector))

	a_feature_vector = infile.readline()

		
