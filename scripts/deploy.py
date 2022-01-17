from brownie import AutiCoin, MarketPlace, accounts, network
from scripts.helpful_scripts import get_account, get_contract


def deploy(price_feed):
    account = get_account()
    auti_coin = AutiCoin.deploy({"from": account})
    market_place = MarketPlace.deploy(price_feed, {"from": account})
    return auti_coin, market_place


def main():
    deploy()
