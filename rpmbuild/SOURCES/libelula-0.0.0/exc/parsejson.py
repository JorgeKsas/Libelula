#!/usr/bin/env python
# -*- coding: utf-8 -*- 

import sys
import json

with open(sys.argv[1]) as f:
	softwares = json.load(f)

if sys.argv[2] == "":
	list_names = []
	duplicated = False
	for software in softwares:
		if software["name"] in list_names:
			duplicated = True
		else:
			list_names.append(software["name"])

	if duplicated:
		print "duplicated"
	else:
		print "correct"
else:
	for software in softwares:
		software["name"]
		if software["name"] == sys.argv[2]:
			for title in software.keys():
				line="%s=%s" % (title, software[title])
				print line.encode('utf-8')
