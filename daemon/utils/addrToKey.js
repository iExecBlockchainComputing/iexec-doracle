"use strict";
exports.__esModule = true;
var ethers_1 = require("ethers");
function default_1(addr) {
    return ethers_1.ethers.utils.hexZeroPad(addr, 32).toString().toLowerCase();
}
exports["default"] = default_1;
