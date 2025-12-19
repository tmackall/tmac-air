#!/bin/bash

git checkout --orphan develop
git rm -rf .
git commit --allow-empty -m "root commit"


