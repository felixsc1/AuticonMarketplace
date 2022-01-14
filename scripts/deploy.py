from brownie import autiCoin, MarketPlace, accounts, network
from helpful_scripts import get_account


def deploy():
    account = get_account()
    auti_coin = autiCoin.deploy({"from": account})
    market_place = MarketPlace.deploy({"from": account})
    return auti_coin, market_place


def main():
    deploy()
