# Marketplace contract

A marketplace that allows trading of any NFT contracts and allows payment with any token by converting the prices.

## Functionality:

- Seller sets price in USD (this is simply because most price feeds are with respect to USD).
- Contract owner can add any tokens to allowed token list (provided that there exists a price feed for conversion)
- Buyer can pay with any token by providing the token address.
- When calling the function buyOfferedItem() USD price will automatically be converted to the specified token, and corresponding amount of tokens will be requested from buyers wallet.
- The function getTokenValue() can be used to check the price for a given Token.


## Possible future improvements

- Allow partial payments with multiple tokens (e.g. 50% in ETH, 50% in auticoins)

## References
This is a combination of other projects:
- [Here](https://github.com/felixsc1/defi-stake-yield-brownie) is an example of how to combine multiple ERC20 tokens, get their exchange rates, etc.

- [Here](https://github.com/felixsc1/NFT-marketplace) is an example how to trade NFTs on a third party contract.