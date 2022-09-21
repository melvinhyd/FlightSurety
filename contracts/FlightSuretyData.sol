pragma solidity >=0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) AuthorizedCallers;
    uint256 private contractBalance = 10 ether;

    struct Airline {   
        bool isRegistered;
        bool isFunded;
        address airlineAddress;
    }
    mapping(address => Airline) public RegisteredAirlines; //Registered airlines mapping
    address[] private registered; //Array of airline addresses


    struct Passenger {   
        bool isInsured;
        bool[] isPaid;
        uint256[] insurancePaid;
        string[] flights;
    }
    mapping(address => Passenger) public InsuredPassengers; //Passenger mapping

    //Flight to passenger mapping
    mapping(string => address[]) FlightPassengers;

    //Flight to totalInsured Amount mapping
    mapping(string => uint256) private FlightInsuredAmount;

    //Passenger address to insurance payment (Insurance payouts for passengers)
    mapping(address => uint256) private InsurancePayment;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
            (
            
            ) 
            public 
            payable
    {
        contractOwner = msg.sender;
        registerFirstAirline(msg.sender);      
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireAuthorizedCaller()
    {
        require(AuthorizedCallers[msg.sender] == true, "Caller is not authorized");
        _;
    }

    /**
    * @dev Modifier that requires the caller is a registered airline
    */
    modifier requireRegisteredAirline(address _airline)
    {
        require(RegisteredAirlines[_airline].isRegistered == true, "Caller is not a registered airline");
        _;
    }

    /**
    * @dev Modifier that requires the caller is a funded airline
    */
    modifier requireFundedAirline(address _airline)
    {
        require(RegisteredAirlines[_airline].isFunded == true, "Caller is not a funded airline");
        _;
    }

     /**
    * @dev Modifier that requires the caller withdraw less than or equal to owed
    */
    modifier checkAmount(address passenger) {
        require(InsurancePayment[passenger] > 0, "There is no payout.");
        _;
        InsurancePayment[passenger] = 0;
        passenger.transfer(InsurancePayment[passenger]);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /**
    * @dev Authorize the calling contract
    */      
    function authorizeCaller(address _caller) public requireContractOwner
    {
        AuthorizedCallers[_caller] = true;
    }

    //Check if caller is authorized
    function isAuthorized(address _caller) public view returns(bool) 
    {
        return AuthorizedCallers[_caller];
    }

    //De-authorizes a caller
    function deAuthorizeCaller(address _caller) public requireContractOwner
    {
        AuthorizedCallers[_caller] = false;
    }

    /**
    * @dev check if airline is registered
    *
    * @return A bool 
    */      
    function isRegistered(address airline) public view returns(bool) 
    {
        return RegisteredAirlines[airline].isRegistered;
    }

    /**
    * @dev check if airline is funded
    *
    * @return A bool 
    */      
    function isFunded(address airline) public view returns(bool) 
    {
        return RegisteredAirlines[airline].isFunded;
    }

    /**
    * @dev check if passenger is insured
    *
    * @return A bool 
    */      
    function isInsured(address passenger, string memory flight) public view returns(bool success) 
    {
        //success = false;
        uint index = getFlightIndex(passenger, flight);
        if(index > 0) 
        {
            success = true;
        }else {
            success = false;
        }
        return success;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * @dev Register first airline
    *
    */  
    function registerFirstAirline (address _airline) internal requireIsOperational
    {
        require(msg.sender == contractOwner, "Unauthorized to use this function");
        RegisteredAirlines[_airline] = Airline({isRegistered: true, isFunded: false, airlineAddress: _airline});
        registered.push(_airline);
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
        (   
            address _airline,
            address caller
        )
        external
        requireIsOperational
        requireAuthorizedCaller
        requireRegisteredAirline(caller) 
        requireFundedAirline(caller)
        returns(bool success)
    {
        //Check if airline is already registered
        require(!RegisteredAirlines[_airline].isRegistered, "Airline is already registered.");

        RegisteredAirlines[_airline] = Airline({isRegistered: true, isFunded: false, airlineAddress: _airline});
        success = true;
        
        return (success);
    }

    /**
    * @dev Get Number of airlines registered
    *
    */   
    function _getRegisteredAirlinesNum() 
        external 
        view
        requireIsOperational
        returns
        (
            uint256 number
        )
    {
        //Get the number of airlines registered
        number = registered.length;
        return number;
    }



   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
        (   
            string memory flight,
            uint256 time,
            address passenger,
            address sender,
            uint256 amount                               
        )
        public
        requireIsOperational
        requireAuthorizedCaller
    {
        string[] memory _flights = new string[](5);
        bool[] memory paid = new bool[](5);
        uint256[] memory insurance = new uint[](5);
        uint index;
        
        //If passenger already insured before
       if(InsuredPassengers[passenger].isInsured == true){
            //check if passenger is trying to re-insure same flight
            index = getFlightIndex(passenger, flight) ;
            require(index == 0, "Passenger already insured for this flight");

            //Add new flight insurance info
            InsuredPassengers[passenger].isPaid.push(false);
            InsuredPassengers[passenger].insurancePaid.push(amount);
            InsuredPassengers[passenger].flights.push(flight);
           
        }else { 
            paid[0] = false; //set isPaid to false
            insurance[0] = amount; //Set insurance premium amount
            _flights[0] = flight; //Set flight 
            InsuredPassengers[passenger] = Passenger({isInsured: true, isPaid: paid, insurancePaid: insurance, flights: _flights}); 
         }
        contractBalance = contractBalance.add(amount);
        FlightPassengers[flight].push(passenger);
        FlightInsuredAmount[flight] = FlightInsuredAmount[flight].add(amount);  
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
        (
            string  flight
        )
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        address[] memory passengers = new address[](FlightPassengers[flight].length);
        uint index;
        uint amount = 0;
        passengers = FlightPassengers[flight];

        for(uint i = 0; i < passengers.length; i++){
            index = getFlightIndex(passengers[i], flight) - 1;
            if(InsuredPassengers[passengers[i]].isPaid[index] == false){
                InsuredPassengers[passengers[i]].isPaid[index] = true;
                amount = (InsuredPassengers[passengers[i]].insurancePaid[index]).mul(15).div(10);
                InsurancePayment[passengers[i]] = InsurancePayment[passengers[i]].add(amount); 
            }
        } 
    }

    /**
     *  @dev Get Index array of Flight
     *
    */
    function getFlightIndex(address pass, string memory flight) public view returns(uint index)
    {
        //uint num = InsuredPassengers[pass].flights.length;
        string[] memory flights = new string[](5);
        flights = InsuredPassengers[pass].flights;
        
        for(uint i = 0; i < flights.length; i++){
            if(uint(keccak256(abi.encodePacked(flights[i]))) == uint(keccak256(abi.encodePacked(flight)))) {
               return(i + 1);
           }
        }

        return(0);
    }

    /**
     *  @dev Get Insured Amount
     *
    */
    function getInsuredAmount
        (
            string  flight,
            address passenger
        )
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns(uint amount)
    {
        amount = 0;
        
        uint index = getFlightIndex(passenger, flight) - 1;
        if(InsuredPassengers[passenger].isPaid[index] == false)
        {
            amount = InsuredPassengers[passenger].insurancePaid[index];
        } 
        return amount;
    }

    /**
     *  @dev Set Insured Amount
     *
    */
    function setInsuredAmount
        (
            string  flight,
            address passenger,
            uint amount
        )
        external
        requireIsOperational
        requireAuthorizedCaller
    {
        uint index = getFlightIndex(passenger, flight) - 1;
        InsuredPassengers[passenger].isPaid[index] = true;
        InsurancePayment[passenger] = InsurancePayment[passenger].add(amount);
    } 


    /**
     *  @dev Get passengers insured
    */
    function getPassengersInsured
        (
            string flight
        )
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns(address[] passengers)
    {
        return FlightPassengers[flight];
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
        (
            address payee
        )
        external
        payable
        requireIsOperational
    {
        require(InsurancePayment[payee] > 0, "There is no payout.");
        uint amount  = InsurancePayment[payee];
        InsurancePayment[payee] = 0;
        contractBalance = contractBalance.sub(amount);
        payee.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
        (   
            uint256 fundAmt,
            address sender
        )
        public
        requireAuthorizedCaller
        requireIsOperational
    {
        RegisteredAirlines[sender].isFunded = true;
        contractBalance = contractBalance.add(fundAmt);
        registered.push(sender);
    }

    /**
    * @dev Get flights insured
    *
    */
    function getFlightsInsured
        (
        address passenger,
        string flight
        )
        external 
        view
        requireIsOperational
        requireAuthorizedCaller
        returns
        (
            bool status
        )
    {
        address[] memory passengers = FlightPassengers[flight];
        status = false;
        for(uint i = 0; i < passengers.length; i++){
            if(passengers[i] == passenger){
                status = true;
                break;
            }
        }
    }

    /**
    * @dev Get flight amount insured
    *
    */
    function getFlightAmountInsured
        (
            string flight
        )
        external 
        view 
        requireIsOperational 
        requireAuthorizedCaller
        returns
        (
            uint amount
        )
    {
        amount = FlightInsuredAmount[flight];
    }

    /**
    * @dev Get Passenger credits
    *
    */
    function getPassengerCredits
        (
            address passenger
        )
        external
        view
        requireIsOperational
        requireAuthorizedCaller
        returns
        (
            uint amount
        )
    {
        return InsurancePayment[passenger];
    }

    /**
    * @dev Get contract balance
    *
    */
    function getContractBalance() external view requireIsOperational returns(uint balance)
    {
        return contractBalance;
    }

    /**
    * @dev Get Address balance
    *
    */
    function getAddressBalance() public view requireIsOperational returns(uint balance)
    {
        return address(this).balance;
    }

    function getFlightKey
        (
            address airline,
            string memory flight,
            uint256 timestamp
        )
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function receive() public payable requireIsOperational
    {

    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        receive();
    }


}

