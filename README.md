# Crosschain-multicall

[![CI - build](https://github.com/ether-wan/crosschain-multicall/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ether-wan/crosschain-multicall/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/ether-wan/crosschain-multicall) 



## Description

**Crosschain Multicall** using Layer0 to transmit calldata between chains. Gas fees are estimated and paid from the source chain, allowing you to execute a write function on a remote chain without needing gas on that destination chain.
## Installation

1. Clone the repository:

  ```sh 
  git clone https://github.com/ether-wan/crosschain-multicall
  ```

2. Install the necessary dependencies:
  ```sh
  npm install
  ```

3. Run the tests:
  ```sh
forge test
  ```

## Acknowledgements

This repository is inspired by or directly modified from many sources, primarily:

- [Multicall](https://github.com/mds1/multicall/)
- [Multicaller](https://github.com/Vectorized/multicaller)