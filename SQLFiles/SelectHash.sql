SET NOCOUNT ON
SELECT [siteid]
      ,[PIDHASH]
      ,[fnamelnamedobssn]
      ,[lnamefnamedobssn]
	  ,[fnamelnamedob]
	  ,[lnamefnamedob]
	  ,[fnamelnameTdobssn]
	  ,[fnamelnameTdob]
	  ,[fname3lnamedobssn]
	  ,[fname3lnamedob]
	  ,[fnamelnamedobDssn]
	  ,[fnamelnamedobYssn]
FROM $(hashTable)