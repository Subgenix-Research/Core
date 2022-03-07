build:
	forge build && \
	npx hardhat compile

clean:
	forge clean

test:
	forge clean && \
	forge test

snap:
	forge snapshot
