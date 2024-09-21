// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FunctionsClient} from "@chainlink/contracts@1.2.0/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.2.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts@1.2.0/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract SepoliaGettingStartedFunctionsConsumer is
    FunctionsClient,
    ConfirmedOwner
{
    using FunctionsRequest for FunctionsRequest.Request;

    string public baseUrl;
    uint64 public subscriptionId;
    address[] public verifiedUsers;
    mapping(address => address[]) public supportedDelegates;

    // Event to log responses
    event Response(bytes32 indexed requestId, bytes data, bytes error);

    event RequestSend(bytes32 requestId);

    event Stringified(string methodName, string result);

    // Router address - Hardcoded for Sepolia
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    string source =
        "const baseUrl = args[0]"
        "const endPoint = args[1];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: `${baseUrl}/${endPoint}`,"
        "headers: {\"X-Wallet-Address\":args[2]},"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data.data);";

    string src_with_body =
        "const baseUrl = args[0]"
        "const endPoint = args[1];"
        "const body = args[2]"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: `${baseUrl}/${endPoint}/`,"
        "method:\"POST\","
        "headers: {\"Content-Type\": \"application/json\", \"X-Wallet-Address\":args[3]},"
        "data: `${body}`"
        "});"
        "if (apiResponse.error) {"
        "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "return Functions.encodeString(data.data);";

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(string memory _baseUrl, uint64 _subId)
        FunctionsClient(router)
        ConfirmedOwner(msg.sender)
    {
        baseUrl = _baseUrl;
        subscriptionId = _subId;
    }

    function changeBaseUrl(string memory _url) external onlyOwner{
        baseUrl = _url;
    }

    // modifier so that only verified contracts can access the DBs
    modifier onlyVerifiedUser() {
        bool verified = false;
        uint256 l = verifiedUsers.length;
        for (uint256 idx = 0; idx < l; idx++) {
            if (verifiedUsers[idx] == msg.sender) {
                verified = true;
                break;
            }
        }
        require(verified, "Unauthorised access");
        _;
    }

    function registerSelf() external payable {
        require(msg.value >= 100000000);
        verifiedUsers.push(msg.sender);
        supportedDelegates[msg.sender] = [msg.sender];
        // now this contract/address can also use our SDK
    }

    function unregisterSelf() external payable onlyVerifiedUser {
        uint256 l = verifiedUsers.length;
        uint256 idx;
        for (idx = 0; idx < l; idx++) {
            if (verifiedUsers[idx] == msg.sender) {
                break;
            }
        }
        verifiedUsers[idx] = verifiedUsers[l - 1];
        verifiedUsers.pop();
        payable(msg.sender).transfer(90000000);
    }

    function addDelegates(address addr) external onlyVerifiedUser {
        supportedDelegates[msg.sender].push(addr);
    }

    modifier onlyDelegates(address verifiedUser) {
        uint256 l = supportedDelegates[verifiedUser].length;
        bool delegate = false;
        for (uint256 idx = 0; idx < l; idx++) {
            if (msg.sender == supportedDelegates[verifiedUser][idx]) {
                delegate = true;
            }
        }
        require(delegate, "Unauthorized");
        _;
    }

    function sendGetRequest(string[] memory args)
        internal
        returns (bytes32 requestId)
    {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        return _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );
    }

    function sendPostRequest(string[] memory args)
        internal
        returns (bytes32 requestId)
    {
        // require(args.length == 3, "Bad args");
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(src_with_body); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );
        return s_lastRequestId;
    }

    function stringifyArray(string[] memory _array)
        public
        pure
        returns (string memory)
    {
        string memory output = "[";
        for (uint256 i = 0; i < _array.length; i++) {
            output = strConcat(output, _array[i]);
            if (i < _array.length - 1) {
                output = strConcat(output, ", ");
            }
        }
        output = strConcat(output, "]");
        return output;
    }

    function strConcat(string memory _a, string memory _b)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(_a, _b));
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function addrToStr(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(
                uint8(uint256(uint160(x)) / (2**(8 * (19 - i))))
            );
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function createDatabase(string memory dbType, string memory dbName)
        external
        onlyVerifiedUser
        returns (bytes32 requestId)
    {
        string[] memory args = new string[](4);
        args[0] = baseUrl;
        args[1] = "db";
        string memory p1 = "{\"type\":\"";
        string memory p2 = "\",\"dbName\":\"";
        string memory p3 = "\"}";
        // string memory p6 = string.concat(
        //     p4,
        //     string.concat(stringifyArray(fieldTypes), p5)
        // );
        // string memory p7 = string.concat(
        //     tableName,
        //     string.concat(p3, string.concat(stringifyArray(fieldNames), p6))
        // );
        args[2] = string.concat(p1, string.concat(dbType, string.concat(p2, string.concat(dbName, p3))));
        emit Stringified("createDatabase", args[2]);
        args[3] = addrToStr(msg.sender);
        return sendPostRequest(args);
    }

    function createTable(
        address owner,
        string memory dbId,
        string memory tableName,
        string[] memory fieldNames,
        string[] memory fieldTypes
    ) external onlyDelegates(owner) returns (bytes32 requestId) {
        string[] memory args = new string[](3);
        args[0] = baseUrl;
        args[1] = string.concat(dbId, string.concat("/", "tables"));
        string memory p1 = "{\"dbName\":\"";
        p1 = string.concat(p1, dbId);
        string memory p2 = "\",\"tableName\":\"";
        p1 = string.concat(p1, p2);
        p1 = string.concat(p1, tableName);
        p2 = "\",\"columnNames\":\"";
        p1 = string.concat(p1, p2);
        p1 = string.concat(p1, stringifyArray(fieldNames));
        p2 = "\",\"columnTypes\":\"";
        p1 = string.concat(p1, p2);
        p1 = string.concat(p1, stringifyArray(fieldTypes));
        p2 = "\"}";
        p1 = string.concat(p1, p2);
        // string memory p6 = string.concat(
        //     p4,
        //     string.concat(stringifyArray(fieldTypes), p5)
        // );
        // string memory p7a = string.concat(
        //     tableName,
        //     p3
        // );
        // string memory p7b = string.concat(stringifyArray(fieldNames), p6);
        // string memory p7 = string.concat(p7a, p7b);
        // args[2] = string.concat(p1, dbId);
        // args[2] = string.concat(args[2], string.concat(p2, p7));
        args[2] = p1;
        emit Stringified("createTable", args[2]);
        args[3] = addrToStr(msg.sender);
        return sendPostRequest(args);
    }

    function getAllRowsOfTable(address owner, string memory dbId, string memory tableId) external onlyDelegates(owner) returns (bytes32 requestId) {
        string[] memory args = new string[](2);
        args[0] = baseUrl;
        args[1] = string.concat(dbId, string.concat("/", string.concat(tableId, "/data")));
        args[2] = addrToStr(owner);
        return sendGetRequest(args);
    }

    function insertSingleRow(
        address owner,
        string memory dbId,
        string memory tableId,
        string[] memory data
    ) external onlyDelegates(owner) returns (bytes32 requestId) {
        string[] memory args = new string[](3);
        args[0] = baseUrl;
        args[1] = "insertSingleRow";
        string memory p1 = "{\"dbName\":\"";
        string memory p2 = "\",\"tableName\":\"";
        string memory p3 = "\",\"rowData\":\"";
        string memory p4 = "\"}";
        string memory stringified_data = stringifyArray(data);
        args[2] = string.concat(p1, string.concat(dbId, p2));
        args[2] = string.concat(args[2], string.concat(tableId, p3));
        args[2] = string.concat(args[2], string.concat(stringified_data, p4));
        emit Stringified("insertSingleRow", args[2]);
        args[3] = addrToStr(msg.sender);
        return sendPostRequest(args);
    }

    function innerStringify(string[] memory _array) public pure returns (string memory) {
        string memory output = "";
        for (uint256 i = 0; i < _array.length; i++) {
            output = strConcat(output, "'");
            output = strConcat(output, _array[i]);
            output = strConcat(output, "'");
            if (i < _array.length - 1) {
                output = strConcat(output, ",");
            }
        }
        return output;
    }

    function stringifyNested(string[][] memory _arr)
        public
        pure
        returns (string memory)
    {
        uint l = _arr.length;
        string[] memory arr = new string[](l);
        for (uint idx = 0; idx < l; idx++){
            arr[idx] = innerStringify(_arr[idx]);
        }
        string memory output = "[";
        for (uint idx = 0;idx<l-1;idx++){
            output=string.concat(output, string.concat(arr[idx], ","));
        }

        return string.concat(output, string.concat(arr[l-1],"]"));
    }

    function insertMultipleRows(
        address owner,
        string memory dbId,
        string memory tableId,
        string[][] memory rows
    ) external onlyDelegates(owner) returns (bytes32 requestId) {
        string[] memory args = new string[](3);
        args[0] = baseUrl;
        args[1] = "insertMultipleRows";
        string memory p1 = "{\"dbId\":\"";
        string memory p2 = "\",\"tableId\":\"";
        string memory p3 = "\",\"data\":\"";
        string memory p4 = "\"}";
        string memory stringified_data = stringifyNested(rows);
        args[2] = string.concat(p1, string.concat(dbId, p2));
        args[2] = string.concat(args[2], string.concat(tableId, p3));
        args[2] = string.concat(args[2], string.concat(stringified_data, p4));
        emit Stringified("insertMultipleRows", args[2]);
        args[3] = addrToStr(msg.sender);
        return sendPostRequest(args);
    }

    // function createCollection(string memory dbId, string memory collectionName)
    //     external
    //     onlyVerifiedUser
    //     returns (bytes32 requestId)
    // {
    //     string[] memory args = new string[](3);
    //     args[0] = baseUrl;
    //     args[1] = "createCollection";
    //     args[2] = string.concat("{\"collectionName\":\"", string.concat(collectionName, "\"}"));
    //     return sendPostRequest(args);
    // }

    function insertSingleDocument(
        address owner,
        string memory dbId,
        string[] memory keys,
        string[] memory values,
        string[] memory types
    ) external onlyDelegates(owner) returns (bytes32 requestId) {}

    function insertMultipleDocuments(
        address owner,
        string memory dbId,
        string[][] memory keys,
        string[][] memory values,
        string[][] memory types
    ) external onlyDelegates(owner) returns (bytes32 requestId) {}

    /**
     * @notice Sends an HTTP request for character information
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendGetRequest(string[] calldata args)
        internal
        returns (bytes32 requestId)
    {
        // require(args.length == 2, "Bad args");
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    function sendRequestTest(string[] calldata args)
        external
        onlyOwner
        returns (bytes32 requestId)
    {
        // require(args.length == 2, "Bad args");
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // just emit a response
        emit Response(requestId, response, err);
    }
}

