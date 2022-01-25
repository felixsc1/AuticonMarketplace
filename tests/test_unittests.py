from brownie import exceptions, Wei, SpectrumToken, accounts
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
    spectrum_token = SpectrumToken.deploy({"from": owner})
    # ACT
    market_place.addAllowedToken("ST",
                                 spectrum_token.address, price_feed_address, {"from": owner})
    # ASSERT
    assert market_place.tokenPriceFeedMapping(
        spectrum_token.address) == price_feed_address
    # Trying to set price feed from non-owner address should give an error:
    with pytest.raises(AttributeError):
        # for some reason with ganache 0.7 brownie exceptions.VirtualMachineError doesn't work here anymore
        market_place.addAllowedToken("ST",
                                     spectrum_token.address, price_feed_address, {"from": non_owner})
    # also testing the function that checks for allowed tokens
    assert market_place.tokenIsAllowed(
        "ST", {"from": non_owner}) == True


def test_token_value(market_place_auti_coin):
    """ Test whether the math in the currency conversion works out.
        Especially whether the number of decimals is correct.
        In mock price feed we have set 1 Token = 2000$

    Args:
        deploy_and_add_token: fixture from conftest.py
    """
    market_place, auti_coin = market_place_auti_coin
    account = get_account()
    # Since we have 8 decimals "too many" from price feed
    expected_value = 2000*10**8 * Wei("50 ether") / (10**8)
    # Test for native currency
    returned_value = market_place.getTokenValue(
        Wei("50 ether"), {"from": account})
    assert returned_value == expected_value
    # Test for ERC20 token (AC has no price feed, ST has)
    returned_value = market_place.getTokenValue(
        Wei("50 ether"), "ST", {"from": account})
    assert returned_value == expected_value


def test_can_create_new_offer(market_place_auti_coin, example_nft):
    """Have an NFT owner create a new offer on the market contract.
        To check if it correctly shows up under the listings.
    Args:
        market_place_auticoin: deployed market contract
        example_nft: deployed and minted NFT
    """
    # Arrange
    market_place, auti_coin = market_place_auti_coin
    account1 = get_account()
    account2 = get_account(index=1)  # account2 is the NFT owner
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
    # with pytest.raises(exceptions.VirtualMachineError):
    with pytest.raises(AttributeError):
        market_place.createNewOffer(
            example_nft.address, 1, 100*10**18, {"from": account1})


def test_can_buy_offer_in_ethereum(market_place_auti_coin, example_nft):
    """
    Seller creates example NFT offer for 1000$
    Buyer buys the offer by paying with native currency.
    SalesTax is sent to the admin.
    needs separate test since transfer functions are different.
    """
    # Arrange
    market_place, auti_coin = market_place_auti_coin
    admin = get_account()  # contract admin
    nft_seller = get_account(index=1)
    nft_buyer = get_account(index=2)
    initial_balance_buyer = nft_buyer.balance()
    initial_balance_seller = nft_seller.balance()
    initial_balance_admin = admin.balance()
    price = 1000*10**18
    example_nft.approve(market_place.address, 1, {"from": nft_seller})
    market_place.createNewOffer(
        example_nft.address, 1, price, {"from": nft_seller})
    price_in_eth = market_place.USDtoETH(
        price)
    sales_tax = price_in_eth / 100 * 10  # 10% fee was set during deployment
    # Act
    # Buyer "accidentally" sends too much ETH
    market_place.buyOfferedItem(
        1, {"from": nft_buyer, "value": price_in_eth+1*10**18})
    # Assert
    assert example_nft.ownerOf(1) == nft_buyer
    # Seller should receive the price minus the sales tax
    assert initial_balance_seller + price_in_eth - sales_tax == nft_seller.balance()
    # Check if buyer only paid the price and got reimbursed for any excess ETH.
    # by default gas fee for ganache is zero, so this calculation should add up:
    assert initial_balance_buyer - price_in_eth == nft_buyer.balance()
    # Check if admin received the sales tax
    assert initial_balance_admin + sales_tax == admin.balance()


def test_can_buy_offer_in_auticoin(market_place_auti_coin, example_nft):
    """
    Seller creates example NFT offer for 1000$
    Buyer buys the offer by paying with AutiCoin.

    """
    # Arrange
    market_place, auti_coin = market_place_auti_coin
    admin = get_account()
    nft_seller = get_account(index=1)
    nft_buyer = get_account(index=2)
    initial_balance_seller = auti_coin.balanceOf(nft_seller)
    price = 1000*10**18  # in USD = AutiCoin
    sales_tax = price / 100 * 10  # 10% fee was set during deployment
    # give the buyer some funds
    auti_coin.transfer(nft_buyer, price, {"from": admin})
    example_nft.approve(market_place.address, 1, {"from": nft_seller})
    market_place.createNewOffer(
        example_nft.address, 1, price, {"from": nft_seller})
    # Act
    auti_coin.approve(market_place.address, price, {"from": nft_buyer})
    market_place.buyOfferedItem(
        1, "AC", {"from": nft_buyer})
    assert example_nft.ownerOf(1) == nft_buyer
    assert auti_coin.balanceOf(
        nft_seller) == initial_balance_seller + price - sales_tax


def test_adding_new_payment_token(market_place_auti_coin):
    market_place, auti_coin = market_place_auti_coin
    market_place.addAllowedToken("GBP", accounts[2], accounts[3])
    assert market_place.tokenIsAllowed("GBP") == True
    assert market_place.tokenSymbolAddressMapping("GBP") == accounts[2]
