from brownie import AutiCoin, MarketPlace, network, config
from scripts.helpful_scripts import get_account, get_contract


def deploy(price_feed):
    account = get_account()
    auti_coin = AutiCoin.deploy(
        {"from": account}, publish_source=config["networks"][network.show_active()].get("verify"))
    market_place = MarketPlace.deploy(
        price_feed, auti_coin.address, 10, {"from": account}, publish_source=config["networks"][network.show_active()].get("verify"))
    return auti_coin, market_place


def main():
    price_feed = get_contract("eth_usd_price_feed")
    deploy(price_feed)
