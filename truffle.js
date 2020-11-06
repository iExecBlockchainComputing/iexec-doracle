module.exports =
{
	networks:
	{
		development:
		{
			host:       "localhost",
			port:       8545,
			network_id: "*",
			gasPrice:   8000000000, // 8 Gwei
		}
	},
	compilers: {
		solc: {
			version: "0.6.12",
			settings: {
				optimizer: {
					enabled: true,
					runs: 200
				}
			}
		}
	},
	mocha:
	{
		enableTimeouts: false
	}
};
