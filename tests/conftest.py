import pytest
from scripts.deploy import deploy
from scripts.helpful_scripts import get_account, get_contract
from brownie import ExampleNFT


@pytest.fixture
def market_place_auticoin():
    account = get_account()
    price_feed_address = get_contract(
        "mock_price_feed")  # Will just return 2000$ value
    auti_coin, market_place = deploy(price_feed_address)
    market_place.addAllowedToken(
        auti_coin.address, price_feed_address, {"from": account})
    return market_place, auti_coin


@pytest.fixture
def example_nft():
    account = get_account(index=1)
    example_nft = ExampleNFT.deploy({"from": account})
    example_nft.mint({"from": account})
    return example_nft
