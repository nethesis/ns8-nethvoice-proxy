#!/usr/bin/env python3

import sys
import os
import agent

variable_name = sys.argv[1]
variable_value =  input(f"Insert value for {variable_name} ({os.getenv(variable_name, '')}): ")

if variable_value:
    agent.set_env(variable_name, variable_value)
