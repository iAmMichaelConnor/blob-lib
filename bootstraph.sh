#!/bin/bash

nvm use 18

yarn install

yarn build

(
    cd contracts

    forge install --no-commit

    git submodule update --init --recursive ./lib

    forge build --evm-version cancun
)

echo "Boostrap complete"