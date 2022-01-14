# Marketplace contract

A marketplace that allows trading of any NFT contracts and allows payment with any token by converting their prices to USD.

## Functionality:
(nothing has been tested yet)

- Seller sets price in USD
- Contract owner can add any tokens to allowed token list (provided that there exists a price feed for conversion)
- Buyer can pay with any token by providing the token address and appropriate amount.
- The function getTokenValue() can be used to determine the price for a given token.


## Possible future improvements

- Allow partial payments with multiple tokens (e.g. 50% in ETH, 50% in auticoins)
- Automatically ask buyer to pay the converted price.

## References
This is a combination of other projects:
- [Here](https://github.com/felixsc1/defi-stake-yield-brownie) is an example of how to combine multiple ERC20 tokens, get their exchange rates, etc.

- [Here](https://github.com/felixsc1/NFT-marketplace) is an example  for an example how to trade NFTs on a third party contract.