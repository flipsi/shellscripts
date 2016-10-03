#!/bin/bash

# install driver and stuff
yaourt -S brother-dcpj315w
yaourt -S brscan4

# setup scanner
sudo sane-find-scanner # yeah?
sudo brsaneconfig4 -a name="NAME" model="MODEL" ip=192...

# scan first image
scanimage --format=png >path/to/file.png
