# CRU-PPRL-registry-hashing-application
This application cleans, combines and hashes patient identifiers using sha512 algorithm. It runs locally without connecting to the web services. It is customized to work with the registry and surveillance data.

Input is a SQL table with the patient identifiers - patient id, first name, last name, date of birth, and SSN (if available).
The hashed combinations are:

    first name + last name + dob + last 4 ssn
    last name + first name + dob + last 4 ssn
    first name + last name + dob
    last name + first name + dob
    first name + last name + Transposed dob + last 4 ssn
    first name + last name + Transposed dob
    first name 3 initial characters + last name + dob + last 4 ssn
    first name 3 initial characters + last name + dob
    first name + last name + dob + 1 day + last 4 ssn
    first name + last name + dob + 1 year + last 4 ssn

Output 1 - a sql table crosswalk with site id, patient id, patient id hash and above hashes.

When using the application, please credit:
Dr. William Trick, Director, Collaborative Research Unit; Kruti Doshi, Lead Developer, Collaborative Research Unit
