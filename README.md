# Crosschain Rebase Token

This project was made following along with a Cyfrin tutorial.

1. A protocol that allows users to deposit into a vault and in return receive rebase tokens that represent their underlying balance.
2. Rebase token -> balanceOf function is dynamic to show the changing balance with time.
   - In this project: Balance increases linearly with time
   - mint tokens to our users everytime they perform an action (minting, burning, transferring, bridging)
3. Interest rate
   1. Individually set an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault
   2. This global interest rate can only decrease to incentivize/reward early adopters

   
`chmod +x ./bridgeToZkSync.sh`

`./bridgeToZkSync.sh`