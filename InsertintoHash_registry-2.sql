/****Hashing Patient identifiers for purpose of matching***/
/****Replace $(Database),$(hashTable),$(temptablename),$(schema),$(sourceTable) with real values****/
/****Replace/map the fields $(patientid),$(name1),$(name2),$(dob),$(ssn) to real columns****/

USE $(Database)
GO

DECLARE @privateSalt VARCHAR(30); SET @privateSalt =''; --up to 30 random characters, do not share this salt
DECLARE @siteid VARCHAR(10); SET @siteid ='Registry';
DECLARE @projectSalt VARCHAR(30); SET @projectSalt ='';--salt used by all sites and registry

IF OBJECT_ID(N'$(hashTable)', N'U') IS NOT NULL
BEGIN
  DROP TABLE $(hashTable)
END;

IF OBJECT_ID(N'tempdb..$(temptablename)', N'U') IS NOT NULL
BEGIN
  DROP TABLE $(temptablename)
END;


SELECT CONCAT(COUNT(*), ' records read')
FROM $(sourceTable)

;with cteclean AS (
SELECT siteid = @siteid
      ,$(patientid) internalid
      ,$(schema).fnRemoveSuffix2($(schema).fnRemovePrefix2($(name1))) name1_0
      ,$(schema).fnRemoveSuffix2($(schema).fnRemovePrefix2($(name2))) name2_0
	  ,CASE WHEN $(dob) IN ('') THEN NULL ELSE CAST($(dob) AS DATE) END dob 
	  ,CASE WHEN $(ssn) IN ('0') THEN NULL ELSE $(schema).fnNumberOnly($(ssn)) END ssn
FROM $(sourceTable)
),

cteunion AS (
SELECT DISTINCT siteid,internalid,$(schema).fnAlphaOnly(name1_0) name1,$(schema).fnAlphaOnly(name2) name2,
                dob,ssn,CASE WHEN names IN ('name2_1','name2_2') THEN 1 ELSE 0 END shy_der_flag
FROM
(
	SELECT siteid
		  ,internalid
		  ,name1_0
		  ,name2_0
		  ,CASE WHEN PATINDEX('% %',name2_0)>0  THEN RIGHT(name2_0, PATINDEX('% %',reverse(name2_0))-1)
				ELSE NULL
		   END name2_1
		  ,CASE WHEN PATINDEX('% %',name2_0)>0  THEN LEFT(name2_0, PATINDEX('% %',(name2_0))-1)
				ELSE NULL
		   END name2_2
		  ,dob
		  ,CASE WHEN ssn IN ('','0000') OR LEN(ssn)<>4 THEN NULL ELSE ssn END ssn
	FROM cteclean
	WHERE 
	  name1_0 NOT LIKE '% BOY %' AND 
	  name1_0 NOT LIKE '% GIRL %' AND 
	  name1_0 NOT LIKE '% BABY %' AND 
	  name1_0 NOT LIKE '% TWIN %' AND
      name1_0 NOT LIKE '% BOY' AND 
	  name1_0 NOT LIKE '% GIRL' AND
	  name1_0 NOT LIKE '% BABY' AND 
	  name1_0 NOT LIKE '% TWIN' AND 
	  name1_0 NOT LIKE 'BOY %' AND
	  name1_0 NOT LIKE 'GIRL %' AND 
	  name1_0 NOT LIKE 'BABY %' AND
	  name1_0 NOT LIKE 'TWIN %' AND
	  name2_0 NOT LIKE '% BOY %' AND 
	  name2_0 NOT LIKE '% GIRL %' AND 
	  name2_0 NOT LIKE '% BABY %' AND 
	  name2_0 NOT LIKE '% TWIN %' AND
      name2_0 NOT LIKE '% BOY' AND 
	  name2_0 NOT LIKE '% GIRL' AND
	  name2_0 NOT LIKE '% BABY' AND 
	  name2_0 NOT LIKE '% TWIN' AND 
	  name2_0 NOT LIKE 'BOY %' AND
	  name2_0 NOT LIKE 'GIRL %' AND 
	  name2_0 NOT LIKE 'BABY %' AND
	  name2_0 NOT LIKE 'TWIN %'
) AS cp
UNPIVOT 
(
  name2 FOR names IN (name2_0,name2_1,name2_2)
) AS up
)

SELECT * INTO $(temptablename)
FROM cteunion
WHERE name1 NOT IN 
      ('UNKNOWN','MALE','FEMALE','BABY','BOY','GIRL','TWINA','TWINB','TWIN','JOHNDOE','JANEDOE',
	   'UNK','TRA','UNKTRA','UNKTRAUMA','UNKNOWNTRAUMA','TRAUMA','PMCERT','UNTRA','PMCERT','') AND
	  name1 IS NOT NULL AND LEN(name1)>1 AND
      name2 NOT IN 
	  ('UNKNOWN','MALE','FEMALE','BABY','BOY','GIRL','TWINA','TWINB','TWIN','JOHNDOE','JANEDOE',
	   'UNK','TRA','UNKTRA','UNKTRAUMA','UNKNOWNTRAUMA','TRAUMA','PMCERT','UNTRA','PMCERT','') AND
	  name2 IS NOT NULL AND LEN(name2)>1 AND
      dob IS NOT NULL  

CREATE NONCLUSTERED INDEX ix_0 ON $(temptablename) (internalid);
CREATE NONCLUSTERED INDEX ix_1 ON $(temptablename) (name1);
--CREATE NONCLUSTERED INDEX ix_2 ON $(temptablename) (name2);
CREATE NONCLUSTERED INDEX ix_3 ON $(temptablename) (dob);
CREATE NONCLUSTERED INDEX ix_4 ON $(temptablename) (ssn);
--CREATE NONCLUSTERED INDEX cx_123 ON $(temptablename) (name1,name2,dob);
--CREATE NONCLUSTERED INDEX cx_213 ON $(temptablename) (name2,name1,dob);
--CREATE NONCLUSTERED INDEX cx_1234 ON $(temptablename) (name1,name2,dob,ssn);
--CREATE NONCLUSTERED INDEX cx_2134 ON $(temptablename) (name2,name1,dob,ssn);
	  
SELECT CONCAT(COUNT(DISTINCT internalid), ' records met criteria')
FROM $(temptablename)

SELECT * INTO $(hashTable) FROM (
SELECT 
siteid
,internalid
,PIDHASH = $(schema).fnHashBytes2(CONCAT(internalid,siteid),@privateSalt)
--,PIDHASH = $(schema).fnHashBytes2(CONCAT(internalid,siteid,datediff(dd,dob,'$(privateDate)')),@privateSalt)
,fnamelnamedobssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                         ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dob,ssn) as varchar(max)),@projectSalt) 
					END
,lnamefnamedobssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                         ELSE $(schema).fnHashBytes2(CAST(CONCAT(name2,name1,dob,ssn) as varchar(max)),@projectSalt) 
					END
,fnamelnamedob = $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dob) as varchar(max)),@projectSalt)
,lnamefnamedob = $(schema).fnHashBytes2(CAST(CONCAT(name2,name1,dob) as varchar(max)),@projectSalt)
,fnamelnameTdobssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,$(schema).fnFormatDate(dob,'YYYY-DD-MM'),ssn) as varchar(max)),@projectSalt)
                     END
,fnamelnameTdob = $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,$(schema).fnFormatDate(dob,'YYYY-DD-MM')) as varchar(max)),@projectSalt)
,fname3lnamedobssn = CASE WHEN ssn IS NULL OR shy_der_flag=1 THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(substring(name1,1,3),name2,dob,ssn) as varchar(max)),@projectSalt)
					 END
,fname3lnamedob = CASE WHEN shy_der_flag=1 THEN CONVERT(VARCHAR(128), NULL)
                       ELSE $(schema).fnHashBytes2(CAST(CONCAT(substring(name1,1,3),name2,dob) as varchar(max)),@projectSalt)   
                  END
,fnamelnamedobDssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dateadd(dd,1,dob),ssn) as varchar(max)),@projectSalt)
					 END
,fnamelnamedobYssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dateadd(YYYY,1,dob),ssn) as varchar(max)),@projectSalt)
					 END
FROM $(temptablename)
) t1
