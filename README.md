# rupabase-smart-contract

This smart contract shall be deployed on the different chains, and users can get themselves authenticated (logic not implemented due to no relation with the project USP).
The address of this contract shall be available to all and after authentication, users can create databases and play with them.

## How-To
- Get yourself registered (either through the admin panel frontend or by sending some ETH to this contract)
- Call functions as per your choice
- Only the registered users can create databases
- A registered user can add other users which currently get the following permissions w.r.t. the databases created by the registered user:
    1. Create Table
    2. Add data to existing tables
    3. View all data

- Currently 4 operations are supported through a total of 5 methods
1. <b>createDatabase</b> - takes in the database type ("SQL" supported currently) and the database name - both strings
- The following methods all take an `owner` argument(other than those mentioned), which is the address of the wallet/contract that signed the database's creation transaction<br>
2. <b>createTable</b> - takes in the `database name`, and two arrays, of which one contains names of all the fields and the second contains the string value corresponding to the type of the field at the same index in the first array.<br>
3. <b>getAllRowsOfTable</b> - takes in the `table name` and the `database name` of the database housing the table
- Inserting into a table involves giving the `table name` and the `database name` of the database housing the table as well as the data to be inserted. Typecasting of data is handled at the backend<br>
4. <b>insertSingleRow</b> - takes in an array, taking in all values of the row to be inserted as strings<br>
5. <b>insertMultipleRows</b> - takes in a 2 dimensional array. Each inner array is a row to be inserted

## Technical details
- `GET` and `POST` requests are made to the off chain backend managing the database using [Chainlink Functions](https://docs.chain.link/chainlink-functions)
- The deployed `Rupabase` contract returns a `requestID` every time a query is made against the database
- When the smart contract gets the response back, it emits a `Response` event containing the `requestId` corresponding to the request which it is fulfilling
- The developer using `Rupabase` is responsible for blocking his/her code if he/she wants synchronous requests
