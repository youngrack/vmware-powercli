#name,samaccountname,surname,givenname,emailaddress,officephone,mobilephone,description
#손영락,yrson,손,영락,yrson@hanaict.co.kr,02-123-4567,010-1234-5678,기술부/손영락

##ActiveDirectory 모듈 추가
Import-Module ActiveDirectory

##csv import
$userlist=import-csv c:\script\add-ad-users-20210426.csv

##위치 지정(OU)
$OUBase = "OU=GII-USERS,OU=GII,DC=gii-vdi,DC=local"

##사용자 추가
foreach($user in $userlist)
{

	$pname=$user.samaccountname+"@gii-vdi.local"
	
	new-aduser -name $user.samaccountname `
	-accountpassword (ConvertTo-SecureString 'GIIvdi1!' -AsPlainText -force) `
	-path "$OUBase" `
	-Surname "$($user.surname)" `
	-GivenName "$($user.givenname)" `
	-displayname "$($user.name)" `
	-EmailAddress "$($user.emailaddress)" `
	-mobilephone "$($user.mobilephone)" `
	-userprincipalname "$pname" `
	-samaccountname $($user.samaccountname) `
	-description "$($user.name)/$($user.description)" `
	-enabled $true `
	-changepasswordatlogon $true
				
	add-adgroupmember -identity 'vdiusergroup' -members $user.samaccountname
	write-host "username :"$user.name" add"
}