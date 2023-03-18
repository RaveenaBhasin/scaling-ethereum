const { ethers } = require("hardhat");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
                       

let gameToken;
let adminThreeCard;
let accounts;

describe("Admin Contract", function () {
    before(async function () {
        accounts = await ethers.getSigners();
        const owner = accounts[0];
        const otherAccount = accounts[1];

        // console.log(owner, otherAccount); 
    
        const GameToken = await ethers.getContractFactory("GameToken");
        gameToken = await GameToken.deploy();
        
        await gameToken.deployed();


        const AdminThreeCard = await ethers.getContractFactory("AdminThreeCard");
        adminThreeCard = await AdminThreeCard.deploy(gameToken.address);

        await adminThreeCard.deployed()

        console.log(gameToken.address, adminThreeCard.address);

        const mintAmount = ethers.utils.parseUnits("1000", 18);

        const ownerBalance = BigNumber.from(await gameToken.balanceOf(owner.address));
        const otherAccountBalance = BigNumber.from(await gameToken.balanceOf(otherAccount.address));

        await gameToken.mint(owner.address, mintAmount);
        await gameToken.mint(otherAccount.address, mintAmount);

        expect(await gameToken.balanceOf(owner.address)).to.equal(ownerBalance.add(BigNumber.from(mintAmount)));
        expect(await gameToken.balanceOf(otherAccount.address)).to.equal(otherAccountBalance.add(BigNumber.from(mintAmount)));

        await gameToken.approve(adminThreeCard.address, mintAmount);
        await gameToken.connect(otherAccount).approve(adminThreeCard.address, mintAmount)

    });

    it("Should be able to create a new game", async function () {
      // const { gameToken, owner, otherAccount, adminThreeCard } = this;
      // console.log(gameToken, owner, otherAccount, adminThreeCard);
      const bootAmount = ethers.utils.parseUnits("1", 18);
      const totalGamesBefore = await adminThreeCard.totalGames();
      console.log("total games before creating new game", ethers.utils.formatUnits(totalGamesBefore, 0));

      expect(await adminThreeCard.createNewGame(bootAmount)).to.emit(adminThreeCard, "GameCreated").withArgs(totalGamesBefore.add(1), anyValue, bootAmount);

      const totalGamesAfter = await adminThreeCard.totalGames();
      console.log("total games before creating new game", ethers.utils.formatUnits(totalGamesAfter, 0));

      expect(totalGamesAfter).to.equal(totalGamesBefore.add(1));
    });
    
    it("Should be able to Enter the game", async function () {
      const gamesInitially = await adminThreeCard.Games(0);

      expect(await adminThreeCard.connect(accounts[1]).enterGame(0)).to.emit(adminThreeCard, "EnteredAGame");
      const gamesAfter = await adminThreeCard.Games(0);

      // console.log(gamesAfter);
      // expect(gameAfter.allPlayerAddresses.length).to.equal(gameInitially.allPlayerAddresses.length + 1);
      expect(gamesAfter.potBalance).to.equal(gamesInitially.potBalance.add(ethers.utils.parseUnits("1", 18)));
    });

    it("Should not be able to Enter the game again", async function () {
      expect(adminThreeCard.connect(accounts[1]).enterGame(0)).to.be.revertedWith("You are already in the game");
    });

    it("Players Should be able to view Cards", async function () {
      const firstPlayer = accounts[0], secondPlayer = accounts[1];
      const myCardsTx = await adminThreeCard.connect(firstPlayer).viewMyCards(0);
      const otherCardsTx = await adminThreeCard.connect(secondPlayer).viewMyCards(0);

      const myCardsRec = await myCardsTx.wait();
      const otherCardsRec = await otherCardsTx.wait();

      console.log(myCardsRec.events?.[0].args?.cards);
      console.log(otherCardsRec.events?.[0].args?.cards);
    });

    it("Should be able to end the game", async function () {
      const firstPlayer = accounts[0], secondPlayer = accounts[1];
      const firstPlayerBalanceBefore = await gameToken.balanceOf(firstPlayer.address);
      const secondPlayerBalanceBefore = await gameToken.balanceOf(secondPlayer.address);

      const game = await adminThreeCard.Games(0);
      const lastMoveAmount = ethers.BigNumber.from(game.lastmove.amount);
      const endGameTx = await adminThreeCard.playMove(0, 1, lastMoveAmount.mul(2), 1);
      const endGameRec = await endGameTx.wait();
      const eventData = endGameRec.events?.filter((e) => e.event === "Scored")?.[0]?.args;
      console.log(eventData?.score, eventData?.playerAddress, eventData?.opponentScore, eventData?.opponentAddress);

      const firstPlayerBalanceAfter = await gameToken.balanceOf(firstPlayer.address);
      const secondPlayerBalanceAfter = await gameToken.balanceOf(secondPlayer.address);
      console.log(firstPlayerBalanceBefore, firstPlayerBalanceAfter, firstPlayer.address);
      console.log(secondPlayerBalanceBefore, secondPlayerBalanceAfter, secondPlayer.address);
    });
});