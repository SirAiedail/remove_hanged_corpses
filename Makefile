#
#  Copyright 2018 Lucas Schwiderski
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

MOD_NAME=remove_hanging_corpses

MODS_DIR=../
RC_DIR=../

BUILD?=release
CONFIG_NAME=itemV2.$(BUILD)

PARAMS=--rc $(RC_DIR) -f '${MODS_DIR}' --cfg ${CONFIG_NAME}

.DEFAULT_GOAL: build
.PHONY: build watch upload publish

build:
	vmb build --source $(PARAMS) $(MOD_NAME)

watch:
	vmb watch $(PARAMS) $(MOD_NAME)

upload: $(build)
	vmb upload $(PARAMS) $(MOD_NAME)

publish: $(build)
	vmb publish $(PARAMS) $(MOD_NAME)
