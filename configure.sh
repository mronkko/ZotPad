#!/bin/sh

#  configure.sh
#  ZotPad
#
#  Created by Mikko Rönkkö on 12/23/12.
#

git submodule init

git submodule foreach git pull
