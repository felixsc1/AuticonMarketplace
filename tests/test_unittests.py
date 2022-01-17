from brownie import exceptions, Wei
from scripts.deploy import deploy
from scripts.helpful_scripts import accounts, get_account, network, LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_contract
import pytest


def test_set_token_and_pricefeed():
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


def test_token_value(market_place_auticoin):
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
