const { exec } = require("child_process");
const { ethers } = require("ethers");

require("dotenv").config();

let isDistributionRunning = false;

function distributeUsdc(simulate = false, ctx = null) {
  return new Promise((resolve, reject) => {
    if (isDistributionRunning) {
      if (ctx != null) {
        let append = simulate ? "simulation" : "";
        ctx.reply(
          `[!] A distribution ${append} is already running, please wait...`
        );
      }
      resolve(0);
      return;
    }

    isDistributionRunning = true;
    ctx.reply(`[+] Simulating USDC output, check back in a few minutes...`);

    let appendBroadcast = (simulate == false) ? "--broadcast" : "";
    exec(
      `forge script script/RDC.s.sol ${appendBroadcast} --skip-simulation --fork-url https://arb1.arbitrum.io/rpc --json | grep -oE '\{.*\}'`,
      (error, stdout, stderr) => {
        if (error) {
          isDistributionRunning = false;
          reject(`Error executing command: ${error}`);
          return;
        }

        const jsonOutput = JSON.parse(stdout.trim());

        isDistributionRunning = false;

        resolve(
          ethers.formatUnits(jsonOutput.returns._usdcOutput.value, 6).toString()
        );
      }
    );
  });
}

async function getPortfolioValue() {
  let url = process.env.DEBANK_API + process.env.SOURCE_WALLET;
  let response = await fetch(url);
  let data = await response.json();
  let usdValue = data.data.usd_value;
  return usdValue;
}

const { Telegraf } = require("telegraf");
const bot = new Telegraf(process.env.BOT_TOKEN);


bot.command("/cash", async (ctx) => {
  let usdValue = await getPortfolioValue();
  usdValue = parseInt(usdValue).toString();
  // add decimal divisors
  usdValue = usdValue.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  // current date in italian format:
  let date = new Date().toLocaleDateString("it-IT");
  ctx.reply(`[${date}] Cash value: $${usdValue},00`);
});

bot.command("simulate", async (ctx) => {
  distributeUsdc(true, ctx).then((usdcOutput) => {
    if (usdcOutput != 0) ctx.reply(`[+] Simulated USDC output: $${usdcOutput}`);
  });
});


bot.command("distribute", async (ctx) => {
    distributeUsdc(false, ctx).then((usdcOutput) => {
      if (usdcOutput != 0) ctx.reply(`[+] $${usdcOutput} USDC transferred!`);
    });
});

bot.command("help", async (ctx) => {
    ctx.reply(
        `Available commands:
        /cash - get cash value
        /simulate - simulate USDC output
        /distribute - distribute USDC`
    );
});

bot.launch();

process.once("SIGINT", () => bot.stop("SIGINT"));
process.once("SIGTERM", () => bot.stop("SIGTERM"));
