USE $(Database)
GO

DECLARE @privateSalt VARCHAR(30); SET @privateSalt ='$(privateSalt)'; --up to 30 random characters
DECLARE @privateDate DATE; SET @privateDate='$(privateDate)'; --date format MM/DD/YYYY e.g.: 01/31/1960
DECLARE @siteid VARCHAR(10); SET @siteid ='$(siteid)';
DECLARE @projectSalt VARCHAR(30); SET @projectSalt ='$(projectSalt)'; 

--while running sql only script, please replace these values:
----$(Database)
----$(privateSalt),$(privateDate)
----$(siteid),$(projectSalt)      --- project based values
----$(hashTable),$(temptablename),$(sourceTable),$(schema),$(patientid),$(name1),$(name2),$(dob),$(ssn)
  

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
	  ,CAST($(dob) AS DATE) dob
	  ,CASE WHEN $(ssn) in (0) THEN NULL ELSE $(schema).fnNumberOnly($(ssn)) END ssn
FROM $(sourceTable)
),

cteunion AS (
SELECT distinct siteid,internalid,$(schema).fnAlphaOnly(name1_0) name1,$(schema).fnAlphaOnly(name2) name2,
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
		  ,CASE WHEN ssn IN ('','0000','1111','2222','3333','4444','5555','6666','7777','8888','9999') OR LEN(ssn)<>4 THEN NULL ELSE ssn END ssn
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
      ('UNKNOWN','MALE','FEMALE','BABY','BOY','GIRL','TWINA','TWINB','TWIN','JOHNDOE','JANEDOE','TEST',
	   'UNK','TRA','UNKTRA','UNKTRAUMA','UNKNOWNTRAUMA','TRAUMA','PMCERT','UNTRA','PMCERT','STUDENTHEALTH',
	   'STUDY','RESEARCH','FOXNEWS','SECURITIES','CORPORATE','EXPOSURE','DOWNTIME','EOHS','') AND
	  name1 IS NOT NULL AND LEN(name1)>1 AND
      name2 NOT IN 
      ('UNKNOWN','MALE','FEMALE','BABY','BOY','GIRL','TWINA','TWINB','TWIN','JOHNDOE','JANEDOE','TEST',
	   'UNK','TRA','UNKTRA','UNKTRAUMA','UNKNOWNTRAUMA','TRAUMA','PMCERT','UNTRA','PMCERT','STUDENTHEALTH',
	   'STUDY','RESEARCH','FOXNEWS','SECURITIES','CORPORATE','EXPOSURE','DOWNTIME','EOHS','') AND
	  name2 IS NOT NULL AND LEN(name2)>1 AND
	  (name1 NOT IN ('JOHN','JON','JANE') AND name2 NOT IN ('DOE')) AND
      dob NOT IN ('') AND dob IS NOT NULL AND DATEDIFF(YEAR,dob,GETDATE()) BETWEEN 0 AND 122 

SELECT CONCAT(COUNT(DISTINCT internalid), ' records met criteria')
FROM $(temptablename)

CREATE NONCLUSTERED INDEX ix_0 ON $(temptablename) (internalid);
CREATE NONCLUSTERED INDEX ix_1 ON $(temptablename) (name1);
--CREATE NONCLUSTERED INDEX ix_2 ON $(temptablename) (name2);
CREATE NONCLUSTERED INDEX ix_3 ON $(temptablename) (dob);
CREATE NONCLUSTERED INDEX ix_4 ON $(temptablename) (ssn);
--CREATE NONCLUSTERED INDEX cx_123 ON $(temptablename) (name1,name2,dob);
--CREATE NONCLUSTERED INDEX cx_213 ON $(temptablename) (name2,name1,dob);
--CREATE NONCLUSTERED INDEX cx_1234 ON $(temptablename) (name1,name2,dob,ssn);
--CREATE NONCLUSTERED INDEX cx_2134 ON $(temptablename) (name2,name1,dob,ssn);

SELECT * INTO $(hashTable) FROM (
SELECT 
siteid
,internalid
,PIDHASH = $(schema).fnHashBytes2(CONCAT(internalid,siteid,datediff(dd,dob,@privateDate)),@privateSalt)
,fnamelnamedobssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                         ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dob,ssn) as varchar(250)),@projectSalt) 
					END
,lnamefnamedobssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                         ELSE $(schema).fnHashBytes2(CAST(CONCAT(name2,name1,dob,ssn) as varchar(250)),@projectSalt) 
					END
,fnamelnamedob = $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dob) as varchar(250)),@projectSalt)
,lnamefnamedob = $(schema).fnHashBytes2(CAST(CONCAT(name2,name1,dob) as varchar(250)),@projectSalt)
,fnamelnameTdobssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,$(schema).fnFormatDate(dob,'YYYY-DD-MM'),ssn) as varchar(250)),@projectSalt)
                     END
,fnamelnameTdob = $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,$(schema).fnFormatDate(dob,'YYYY-DD-MM')) as varchar(250)),@projectSalt)
,fname3lnamedobssn = CASE WHEN ssn IS NULL OR shy_der_flag=1 THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(substring(name1,1,3),name2,dob,ssn) as varchar(250)),@projectSalt)
					 END
,fname3lnamedob = CASE WHEN shy_der_flag=1 THEN CONVERT(VARCHAR(128), NULL)
                       ELSE $(schema).fnHashBytes2(CAST(CONCAT(substring(name1,1,3),name2,dob) as varchar(250)),@projectSalt)   
                  END
,fnamelnamedobDssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dateadd(dd,1,dob),ssn) as varchar(250)),@projectSalt)
					 END
,fnamelnamedobYssn = CASE WHEN ssn IS NULL THEN CONVERT(VARCHAR(128), NULL)
                          ELSE $(schema).fnHashBytes2(CAST(CONCAT(name1,name2,dateadd(YYYY,1,dob),ssn) as varchar(250)),@projectSalt)
					 END
FROM $(temptablename)
) t1