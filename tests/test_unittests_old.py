from brownie import exceptions, Wei
from scripts.deploy import deploy
from scripts.helpful_scripts import accounts, get_account, network, LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_contract
import pytest


def old_test_set_token_and_pricefeed():
    """
    On the local network add an ERC 20 token and mock price feed.
    """
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("only for local unit test.")
    # ARRANGE
    price_feed_address = get_contract(
        "mock_price_feed")  # Will just return 2000$ value
    auti_coin, market_place = deploy(price_feed_address)
    owner = get_account()
    non_owner = get_account(index=1)
    # ACT
    market_place.addAllowedToken(
        auti_coin.address, price_feed_address, {"from": owner})
    # ASSERT
    assert market_place.tokenPriceFeedMapping(
        auti_coin.address) == price_feed_address
    # Trying to set price feed from non-owner address should give an error:
    with pytest.raises(exceptions.VirtualMachineError):
        market_place.addAllowedToken(
            auti_coin.address, price_feed_address, {"from": non_owner})
    # also testing the function that checks for allowed tokens
    assert market_place.tokenIsAllowed(
        auti_coin.address, {"from": non_owner}).return_value == True


def old_test_token_value(market_place_auticoin):
    """ Test whether the math in the currency conversion works out.
        Especially whether the number of decimals is correct.
        In mock price feed we have set 1 Token = 2000$

    Args:
        deploy_and_add_token: fixture from conftest.py
    """
    account = get_account()
    market_place, auti_coin = market_place_auticoin
    # Since we have 8 decimals "too many" from price feed
    expected_value = 2000 * Wei("50 ether") / (10**8)
    # Test for native currency
    returned_value = market_place.getTokenValue(
        Wei("50 ether"), {"from": account})
    assert returned_value == expected_value
    # Test for ERC20 token
    returned_value = market_place.getTokenValue(
        Wei("50 ether"), auti_coin.address, {"from": account})
    assert returned_value == expected_value


def old_test_can_create_new_offer(market_place_auticoin, example_nft):
    """Have an NFT owner create a new offer on the market contract.
        To check if it correctly shows up under the listings.
    Args:
        market_place_auticoin: deployed market contract
        example_nft: deployed and minted NFT
    """
    # Arrange
    account1 = get_account()
    account2 = get_account(index=1)  # account2 is the NFT owner
    market_place, auti_coin = market_place_auticoin
    # Act
    example_nft.approve(market_place.address, 1)
    market_place.createNewOffer(
        example_nft.address, 1, 100*10**18, {"from": account2})
    # Assert
    # 2nd entry of listings object is seller
    assert market_place.showOffer(1)[1] == account2
    # 3rd entry is token address
    assert market_place.showOffer(1)[2] == example_nft.address
    # non-owner of the NFT shouldnt be able to create offer
    with pytest.raises(exceptions.VirtualMachineError):
        market_place.createNewOffer(
            example_nft.address, 1, 100*10**18, {"from": account1})


def old_test_can_buy_offer_in_auticoin(market_place_auticoin, example_nft):
    """
    Seller creates example NFT offer for 1000$
    Buyer buys the offer by paying with AutiCoin.

    """
    # Arrange
    account1 = get_account()  # contract owner and NFT buyer
    account2 = get_account(index=1)  # account2 is the NFT owner
    price = 1000*10**18
    market_place, auti_coin = market_place_auticoin
    example_nft.approve(market_place.address, 1)
    market_place.createNewOffer(
        example_nft.address, 1, price, {"from": account2})
    # Act
    # Use getTokenValue to calculate the price
    price_in_auticoin = market_place.getTokenValue(
        price, auti_coin.address)
    auti_coin.approve(market_place.address, price_in_auticoin)
    market_place.buyOfferedItem(
        1, auti_coin.address, {"from": account1})
    assert example_nft.ownerOf(1) == account1


def old_test_can_buy_offer_in_ethereum(market_place_auticoin, example_nft):
    """
    Seller creates example NFT offer for 1000$
    Buyer buys the offer by paying with native currency.
    needs separate test since transfer functions are different.
    """
    # Arrange
    admin = get_account()  # contract owner and NFT buyer
    nft_seller = get_account(index=1)  # account2 is the NFT owner
    nft_buyer = get_account(index=2)
    price = 1000*10**18
    market_place, auti_coin = market_place_auticoin
    example_nft.approve(market_place.address, 1, {"from": nft_seller})
    market_place.createNewOffer(
        example_nft.address, 1, price, {"from": nft_seller})
    # Act
    price_in_eth = market_place.USDtoETH(
        price)
    market_place.buyOfferedItem(
        1, {"from": nft_buyer, "value": price_in_eth})
    assert example_nft.ownerOf(1) == account1
