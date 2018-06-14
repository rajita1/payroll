pragma solidity ^0.4.24;

/*Smart contract created by Rajita Yerramilli on June 12th, 2018.
  This contract implements functions defined in the PayrollInterface. 
  Omitting import and inheritance from the interface as it's not really needed here,
  and so that it can be easily tested in remix.*/

contract Payroll {

    struct Employee {    
       address accountAddress;
       address[] allowedTokens; 
       uint256 lastPayDay;
       /*Based on the comments in the challenge question, employees can collect pay 
         once every 30 days and pay day might vary within employees*/
         
       uint256 lastTokenDistributionDay;
       
       bool active; 
       
       /*since deleting an element from array of structs leaves values of zero, an
         alternative method could be to set the active flag as false (set to true upon adding an
         employee), and leaving the other values as is). The employee cannot draw a salary if this flag has a value of false. Only the owner
         can set this flag to false. Since it's a boolean, the value is false by default,
         however, during the default value of false, at that point an employee has not been added*/
       
       uint256 initialYearlyEURSalary;  
       
       /*Given the above name, perhaps when an updated salary is set by the owner, there
         should be another element defined in the employee struct for updated salary. for
         now the initialYearlyEURSalary will be updated with the new salary.*/
   }
   
   Employee[] employees;
   /*Using an array here instead of a mapping with employeeId as the key that maps to a struct.
     The reason is that mappings don't store keys. And if I were to verify an employee role,
     the require statement might return true even if the employeeId doesn't exist. The side
     effect of this decision is that the array indices and employee Ids won't match 1:1*/

   mapping (address => uint256) empAddressToId; 
   
  /*This mapping will help identify whether the msg.sender is an employee for the modifier function.
    So the employeeId has to start at 1. A value of zero means there's no employee Id for that account address.
    The key in the above mapping is the employee Id which will be calculated through a counter every 
    time the owner adds an employee. */
    
   mapping (address => uint256[]) public tokenDistribution; //set to public so it can be examined in remix
    
  uint256 employeeCount;
  uint256 employeeIdCounter = 1; 
  
  /*For the sake of simplicity, employee Ids are sequential and start at 1, so that
    the employeeOnly modifier can be tested for an integer of non-default value greater than zero.
    This will cause a difference of 1 between the employees array index and the employee counter.
    Not ideal but can't seem to get around this.*/
  
  address oracle;  //This should be set by the owner before paydays
  address owner; 
  uint256 cumulativeEmployeeSalaries;
  mapping (address => uint256) exchangeRate;
  
  function Payroll (address oracleAddress) public {
  //In order for the contract to have the oracle address, it would have to be set by the owner
         owner = msg.sender;
         oracle = oracleAddress;
    }
    
    modifier ownerOnly() {
       require(msg.sender == owner); //this modifier method ensures that the funcions that use restricted keywork can only be invoked by the admin
       _;
   }
   
   modifier oracleOnly() {
       require(msg.sender == oracle);
       _;
   }

   modifier employeeOnly() {
       require(empAddressToId[msg.sender] > 0 ); 
       /*If an employee exists at this key in the employees array, the value (employer Id) 
         has to be greater than zero based on the setting in addEmployee*/
       _;
   }
   
   function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) public ownerOnly returns (uint256) {
            /*Need to add logic to make sure employee Id key doesn't already exist but I am not aware of a way
              to do this in Solidity and technically it doesn't prevent you from adding the same key twice.
              I modified the function specification so it returns an employee Id*/
            
            uint256 modulus = allowedTokens.length % 2; //needed below for default token distribution

            uint256  distribution = 100 / allowedTokens.length;
            
            require(empAddressToId[accountAddress] == 0); //prevents adding the same employee twice
           
            require(initialYearlyEURSalary > 0);
            
            require(allowedTokens.length <= 10);
            /*The addemployee transaction is signed by the owner's private key, which makes it safe.
              However as an added precaution, the above check sets an upper bound on the array size
              which will affects loops that use these arrays.*/
            
            
            Employee memory employee = Employee({
                                        accountAddress: accountAddress, 
                                        allowedTokens: allowedTokens, 
                                        lastPayDay: 0, 
                                        active: true, 
                                        initialYearlyEURSalary: initialYearlyEURSalary, 
                                        lastTokenDistributionDay: 0
                
                                      });
           employees.push(employee);
            
             //Since distribution is not one of the parameters, setting a uniform default distribution
             for (uint i=0; i < allowedTokens.length; i++) {
                 tokenDistribution[accountAddress].push(distribution);
             //accountAddress is a key in the mapping that holds the token distribution percentages
             }
         
             if (modulus != 0) {
                 tokenDistribution[accountAddress][0] += modulus;
              /*compensate for an odd number distribution by adding the remainder to the
                first element since the distribution has uints and not decimals*/
             }
            
            empAddressToId[accountAddress] = employeeIdCounter;
            //The above statement will help the modifier function determine if the msg.sender is an employee
            
            employeeCount++;
            employeeIdCounter++; 
            
            /*employeeCount would be set to 1 and employeeIdCounter would be set to 2, 
              and would be used to set the employeeId the next time addEmployee is invoked*/
              
            cumulativeEmployeeSalaries += initialYearlyEURSalary;
            return employeeIdCounter;
    }
    
    
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public ownerOnly {
        
        /*This is a setter than can be invoked by the owner for a raise
          assuming that salaries can only be increased.*/
        uint256 oldSalary;
        require(yearlyEURSalary > 0); //check salary value is greater than zero
        Employee storage employee = employees[employeeId - 1]; //difference of 1 between the array index and employee Id Counter
        oldSalary = employee.initialYearlyEURSalary;
        employee.initialYearlyEURSalary = yearlyEURSalary;
        cumulativeEmployeeSalaries += yearlyEURSalary - oldSalary;
        
        /*Update the total yearly salaries that is used to caculate the payroll burn rate 
          by calculating the delta*/
        }
    
    function removeEmployee(uint256 employeeId) public ownerOnly {
       /*what is the process for a terminated or resigned employee to get paid for the
         outstanding balance based on the termination date relative to the last pay date?*/
        Employee storage employee = employees[employeeId - 1];
        //delete empAddressToId[employee.account];
        //delete employees[employeeId];
        /*The above two lines leave zeros as values, which looks confusing, so I decided 
        to set a boolean flag instead. Note - the check in addEmployee prevents from reinstating the same 
        employee at a later time based on account address.*/
        
        employee.active = false;
        employeeCount--;
        cumulativeEmployeeSalaries -= employee.initialYearlyEURSalary;
        
    }
    
    function addFunds() payable public ownerOnly { 
        require(msg.value >= calculatePayrollBurnrate()); //check to verify that it matches the total monthly salaries
   }
    
   function escapeHatch() public ownerOnly {
        selfdestruct(owner);   //transfer all funds to the owner in the event of an unexpected error in the deployed contract
    }
    
    function getEmployeeCount() public ownerOnly constant returns (uint256) {
        return employeeCount;
    }
    
    function getEmployee(uint256 employeeId) public ownerOnly constant returns (address accountAddress, address[] allowedTokens, uint256 lastPayDay, uint256 initialYearlyEURSalary, bool active, uint256 lastTokenDistributionDay) {
        Employee storage employee = employees[employeeId - 1];
        accountAddress = employee.accountAddress;
        allowedTokens = employee.allowedTokens;
        lastPayDay = employee.lastPayDay;
        lastTokenDistributionDay = employee.lastTokenDistributionDay;
        initialYearlyEURSalary = employee.initialYearlyEURSalary;
        active = employee.active;
        
    }
    
    function calculatePayrollBurnrate() public ownerOnly constant returns (uint256) {
        //Based on the comments in the challenge question, this appears to be a way to calculate total monthly salaries, which would be the same for every month
         return cumulativeEmployeeSalaries/12;
    }
    
   //function calculatePayrollRunway() public ownerOnly constant returns (uint256) {} 
    //I am not sure what a runway is in this context.
  
    
    function determineAllocation(address[] tokens, uint256[] distribution) public employeeOnly {
        //Assuming this is a function that allows an employee to allocate percentage distribution of tokens
        
        Employee storage employee = employees[empAddressToId[msg.sender]-1];
        uint256 total;
        require(now >= employee.lastPayDay + 180 days);
        require(tokens.length == distribution.length);
        /*Not checking to verify that the tokens array here matches the tokens from addEmployee
          For simplicity sake, assuming that it's the same set in the same order*/
          
        for (uint256 i=0; i < distribution.length; i++) {
            total += distribution[i];
        }
        require(total == 100);
        //Onus is upon employee to adjust the distribution correctly so it adds up to 100
        
        for (uint256 j=0; j < distribution.length; j++) {
            tokenDistribution[msg.sender][j] = distribution[j];
        }
          
        employee.lastTokenDistributionDay = now;
        
    }
    

    function payday() public employeeOnly {
        
        Employee storage employee = employees[empAddressToId[msg.sender]-1];
        address[] storage tokens = employee.allowedTokens;
        uint256[] storage distribution = tokenDistribution[msg.sender];
        require(now >= employee.lastPayDay + 30 days);
        require(employee.active);
        uint256 monthlySalary = employee.initialYearlyEURSalary/12;  //calculate monthly salary
        
        require(this.balance >= monthlySalary); //ensure contract has adequate balance
        
        for (uint i=0; i < tokens.length; i++ ) {
            require(exchangeRate[tokens[i]] > 0); 
            tokens[i].transfer(monthlySalary*exchangeRate[tokens[i]]*distribution[i]/100);     
            //Draw monthly salary proportion into each allowed token based on distribution percentages
        }
       
        
        employee.lastPayDay = now; //set lastPayDay to current timestamp

    }
    
    function setExchangeRate(address token, uint256 EURExchangeRate) public oracleOnly {
         exchangeRate[token] = EURExchangeRate; 
    }
    
    /*function getDefaultTokenDistribution(uint256 arrayLength) public ownerOnly returns (uint256[]) {
     //Commenting out since Solidity doesn't seem to support returning a dynamic array    
        uint256  distribution = 100 / arrayLength;
        uint256[] storage distArray;
        for (uint i=0; i < arrayLength; i++) {
                 distArray.push(distribution);
             }
        uint256 modulus = arrayLength % 2;
        if (modulus != 0) {
              distArray[0] += modulus; 
              //compensate for an odd number distribution by adding the remainder to the
                //first element since the distribution has uints and not decimals
        }
        return distArray;
    }*/
    
}