#!/bin/bash
source ~/.rvm/environments/ruby-3.3.0
cd ~/git/hegesmart
export HEGETOOL_ENV=staging 
exec bundle exec pry -Iconfig -rboot

