

    Directory: C:\Users\ryan.yates\OneDrive\GitHub\PowerShellModules\PesterHelpers\Scripts


Mode                LastWriteTime         Length Name                                                                                                                                                                                       
----                -------------         ------ ----                                                                                                                                                                                       
-a----       09/03/2018     13:37             14 init.ps1                                                                                                                                                                                   


function Get-CommonParameter {


<#
    .SYNOPSIS
        Helper Function to get all Common Parameters
    .DESCRIPTION
        As synopsis
    .EXAMPLE
    $CommonParameters = (Get-Command Get-CommonParameter | Select-Object -ExpandProperty Parameters).Keys

    This gets all Common Parameters into a Varaible to then be able to remove them from any automation of tests on Parameters
#>
[cmdletbinding(SupportsShouldProcess=$true)]
param()
if ($PSCmdlet.ShouldProcess($null,$null)) { }
 


}

Function Export-AllModuleFunction {
<#
.Synopsis
   Exports All Module Functions into Separate PS1 files

.DESCRIPTION
   Exposes all Private and Public Functions and exports them to a location that you tell it to Export to & Creates a Basic Shell Pester Test for the Function

.PARAMETER Module
    This should be passed the Module Name as a single string - for example 'PesterHelpers'

.PARAMETER OutPath
    This is the location that you want to output all the module files to. It is recommended not to use the same location as where the module is installed.
    Also always check the files output what you expect them to.
.EXAMPLE
   Export-AllModuleFunction -Module TestModule -OutPath C:\TestModule\

   This will get the Module TestModule that is loaded in the Current PowerShell Session and will then iterate through all the Private & Public Functions and
   export them to separate ps1 files with a non-functional test file and a blank Functional tests file created as well.
#>

    [CmdletBinding()]
    [Alias()]
    Param
    (
        
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String]
        $Module,

        [Parameter(Mandatory=$true)]
        [String]
        $OutPath
    )
    $ModuleData = Get-Module $Module -Verbose:$VerbosePreference
    
    If ($null -eq $ModuleData) {throw 'Please Import Module into session'}
    else {
    Write-Verbose "$ModuleData" 
    $PublicFunctions = (Get-command -Module $module).Where{$_.CommandType -ne 'Cmdlet'}
    
    Foreach ($PublicFunction in $PublicFunctions){
    Write-Verbose "Found $($PublicFunction.Name) being Exported"
    }

    $AllFunctions = & $moduleData {Param($modulename) (Get-command -CommandType Function -Module $modulename).Where{$_.CommandType -ne 'Cmdlet'}} $module

    $PrivateFunctions = Compare-Object $PublicFunctions -DifferenceObject $AllFunctions -PassThru -Verbose:$VerbosePreference

    Foreach ($PrivateFunction in $PrivateFunctions){
    Write-Verbose "We Found $($PrivateFunction.Name) that is not being Exported"
    }

    $PublicFunctions | ForEach-Object { Export-Function -Function $_.Name -ResolvedFunction $_ -OutPath $OutPath -Verbose:$VerbosePreference }
    
    $PrivateFunctions | ForEach-Object { Export-Function -Function $_.Name -ResolvedFunction $_ -OutPath $OutPath -PrivateFunction -Verbose:$VerbosePreference }
    }
}
function Export-Function {
 <#
.Synopsis
    Exports a function from a module into a user given path
    
.Description
    As synopsis

.PARAMETER Function
    This Parameter takes a String input and is used in Both Parameter Sets
    
.PARAMETER ResolvedFunction
    This should be passed the Function that you want to work with as an object making use of the following
    $ResolvedFunction = Get-Command "Command"
    
.PARAMETER OutPath
    This is the location that you want to output all the module files to. It is recommended not to use the same location as where the module is installed.
    Also always check the files output what you expect them to.
    
.PARAMETER PrivateFunction
    This is a switch that is used to correctly export Private Functions and is used internally in Export-AllModuleFunction
        
.EXAMPLE
    Export-Function -Function Get-TwitterTweet -OutPath C:\TextFile\
       
    This will export the function into the C:\TextFile\Get\Get-TwitterTweet.ps1 file and also create a basic test file C:\TextFile\Get\Get-TwitterTweet.Tests.ps1

.EXAMPLE
    Get-Command -Module SPCSPS | Where-Object {$_.CommandType -eq 'Function'}  | ForEach-Object { Export-Function -Function $_.Name -OutPath C:\TextFile\SPCSPS\ }    
         
    This will get all the Functions in the SPCSPS module (if it is loaded into memory or in a $env:PSModulePath as required by ModuleAutoLoading) and will export all the Functions into the C:\TextFile\SPCSPS\ folder under the respective Function Verbs. It will also create a basic Tests.ps1 file just like the prior example        
#>
[cmdletbinding(DefaultParameterSetName='Basic')]

Param(
    [Parameter(Mandatory=$true,ParameterSetName='Basic',ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [Parameter(Mandatory=$true,ParameterSetName='Passthru',ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateNotNull()]
    [Alias('Command')]
    [Alias('Name')]
    [String]
    $Function,

    [Parameter(Mandatory=$true,ParametersetName='Passthru')]
    $ResolvedFunction,

    [Parameter(Mandatory=$true,ParameterSetName='Basic')]
    [Parameter(Mandatory=$true,ParameterSetName='Passthru')]
    [Alias('Path')]
    [String]
    $OutPath,

    [Parameter(Mandatory=$false,ParametersetName='Passthru')]
    [Alias('Private')]
    [Switch]
    $PrivateFunction

    )

$sb = New-Object -TypeName System.Text.StringBuilder
 
 If (!($ResolvedFunction)) { $ResolvedFunction = Get-Command $function}
 $code = $ResolvedFunction | Select-Object -ExpandProperty Definition
                
        If (!($PrivateFunction)) {
            $PublicOutPath = "$OutPath\Public\"
            $ps1 = "$PublicOutPath$($ResolvedFunction.Verb)\$($ResolvedFunction.Name).ps1"
        }
        ElseIf ($PrivateFunction) {
            $ps1 = "$OutPath\Private\$function.ps1"
        }

        $sb.AppendLine("function $function {") | Out-Null
        
        foreach ($line in $code -split '\r?\n') {
            $sb.AppendLine('{0}' -f $line) | Out-Null
        }

        $sb.AppendLine('}') | Out-Null

        New-Item $ps1 -ItemType File -Force | Out-Null
        Write-Verbose -Message "Created File $ps1"

        Set-Content -Path $ps1 -Value $($sb.ToString()) -Encoding UTF8
        Write-Verbose -Message "Added the content of function $Function into the file"
        
        If(!($PrivateFunction)) {
        New-FunctionPesterTest -Function $Function -ResolvedFunction $ResolvedFunction -OutPath $PublicOutPath -Verbose:$VerbosePreference
        Write-Verbose -Message "Created a Pester Test file for $Function Under the Basic ParamaterSet" 
        }
        ElseIf ($PrivateFunction) {
        New-FunctionPesterTest -Function $Function -ResolvedFunction $ResolvedFunction -PrivateFunction -OutPath $OutPath -Verbose:$VerbosePreference
        Write-Verbose -Message "Created a Pester Test file for $Function Under the Passthru ParamaterSet" 
        }


}

function New-FunctionFile {
<#
.SYNOPSIS
   This is the Short Description field for $functionName
.DESCRIPTION
   This is the Long Description field for $functionName

.PARAMETER FunctionName

.EXAMPLE
   New-FunctionFile -FunctionName Test-FunctionFile
#>

[Cmdletbinding(SupportsShouldProcess=$true)]
param($FunctionName) 


if ($PSCmdlet.ShouldProcess($OutPath,"Creating function & pester test Files for $Function"))
{
$verb = $functionName.split('-')[0] 
New-Item .\$verb\$functionName.ps1 -Force | Out-Null 

$value = @'
Function $functionName {
<#
.SYNOPSIS
   This is the Short Description field for $functionName

.DESCRIPTION
   This is the Long Description field for $functionName

.PARAMETER FunctionName

.PARAMETER FunctionName

.PARAMETER FunctionName


.EXAMPLE
   $functionName -Param1 -Param2

.EXAMPLE
   Another example of how to use this cmdlet
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Param1,

        # Param2 help description
        [int]
        $Param2
    )

    Begin
    {
    }
    Process
    {
    }
    End
    {
    }
}
'@

$value = $value.Replace('$functionName',$functionName)
Set-Content -Path .\$verb\$functionName.ps1 -Value $value -Encoding UTF8

New-Item .\$verb\$functionName.Tests.ps1 -Force | Out-Null 
}

}

Function New-FunctionPesterTest {
<#
.SYNOPSIS
   This Function Creates 2 Pester Test files for the Function being passed to it

.DESCRIPTION
   This Function creates a skeleton pester test file for the Function that is being passed to it including whether the
   Function has Parameters and creates some basic Pester Tests for these so that you can pull then in future have oppottunity
   to test the code you've written in more detail - This is a Non-Functional Pester Test called <Function>.Tests.ps1

   The Function also creates a blank file in the same location for you to create your Functional Pester Tests and this is created
   called <Function>.Functional.Tests.ps1

.PARAMETER Function
    This Parameter takes a String input and is used in Both Parameter Sets
    
.PARAMETER ResolvedFunction
    This should be passed the Function that you want to work with as an object making use of the following
    $ResolvedFunction = Get-Command "Command"

.PARAMETER OutPath
    This is the location that you want to output all the module files to. It is recommended not to use the same location as where the module is installed.
    Also always check the files output what you expect them to.

.PARAMETER PrivateFunction
    This is a switch that is used to correctly export Private Functions and is used internally in Export-AllModuleFunction

.EXAMPLE
   New-FunctionPesterTest -Function New-FunctionPesterTest -OutPath C:\TextFile\PesterHelpers\
.EXAMPLE
   Get-Command -Module MyModule | Select-Object -ExpandProperty Name | ForEach-Object { New-FunctionPesterTest -Function $_ -OutPath C:\TextFile\PesterHelpers\
.EXAMPLE
    In this example we have a PrivateFunction that we need to export - In this case it is Get-CommonParameter

    $Function = 'Get-CommonParameter'
    $Module = 'PesterHelpers'
    $ModuleData = Get-Module $module

    However as it is a Private Function we need to run the following to essentially flush the function into our available local scope
    For this piece of code thanks goes to Bruce Payette @BrucePayette

    $AllFunctions = & $moduleData {Param($modulename) Get-command -CommandType Function -Module $modulename} $module

    $ResolvedFunction = $AllFunctions.Where{ $_.Name -eq $function}

    New-FunctionPesterTest -Function $Function -ResolvedFunction $ResolvedFunction -PrivateFunction -OutPath $OutPath -Verbose

    However it is unlikely that you would need to run something similar to this example though this is added for completeness and
    should help in understanding the story of what happens under the hood

.EXAMPLE
    New-FunctionPesterTest -Function 'New-FunctionPesterTest -OutPath C:\TextFile -Verbose

    This is useful for when you have created a Function and have no tests and could potentially be used with simple scripts that really just encapsulated as 1 function
#>

[CmdletBinding(SupportsShouldProcess=$true,
               DefaultParametersetName='Basic')]
Param(
    [Parameter(Mandatory=$true,ParametersetName='Basic')]
    [Parameter(Mandatory=$true,ParametersetName='Passthru')]
    [String]
    $Function,

    [Parameter(Mandatory=$true,ParametersetName='Passthru')]
    $ResolvedFunction,

    [Parameter(Mandatory=$true,ParametersetName='Basic')]
    [Parameter(Mandatory=$true,ParametersetName='Passthru')]
    [String]
    $OutPath,

    [Parameter(Mandatory=$false,ParametersetName='Passthru')]
    [Switch]
    $PrivateFunction
    )

if ($PSCmdlet.ShouldProcess($OutPath,"Creating Pester test File for $Function"))
{
    $SB               = New-Object -TypeName System.Text.StringBuilder
    $Parameters       = New-Object System.Collections.ArrayList
    $CommonParameters = (Get-Command Get-CommonParameter | Select-Object -ExpandProperty Parameters).Keys
    If (!($ResolvedFunction)) {$ResolvedFunction = Get-Command $Function }
    If (!($PrivateFunction)) {  $Tests = "$OutPath\$($ResolvedFunction.Verb)\Tests\$($ResolvedFunction.Name).Tests.ps1"
                                $FunctionalTests = "$OutPath\$($ResolvedFunction.Verb)\Tests\$($ResolvedFunction.Name).Functional.Tests.ps1" }
    Elseif ($PrivateFunction) { $Tests = "$OutPath\Private\Tests\$Function.Tests.ps1"
                                $FunctionalTests = "$OutPath\Private\Tests\$Function.Functional.Tests.ps1" }
    
    $FunctionParams   = $ResolvedFunction.Parameters.Keys

$VerboseMessage = "Full Output path is $Tests"
Write-Verbose -Message $VerboseMessage

$SecondLine       = @'
Describe '$Function Tests' {


'@

$SecondLine       = $SecondLine.Replace('$Function',$Function)
$SB.Append($SecondLine) | Out-Null

Write-Verbose -Message "Added initial lines to the StringBuilder variable being used"

If ($FunctionParams.Count -gt 0)  {

    $FunctionParams.Foreach({$Parameters.Add($_)}) | Out-Null

    $CommonParameters.Foreach({$Parameters.Remove($_)}) | Out-Null
    Write-Verbose -Message "The Function $Function has $($Parameters.Count) Non-Common Parameters"

    $ThirdLine = @'
   Context 'Parameters for $Function'{


'@
    $ThirdLine = $ThirdLine.Replace('$Function',$Function)
    $SB.Append($ThirdLine) | Out-Null

    Write-Verbose -Message "Added Initial Parameter Lines to StringBuilder Variable"

foreach ($Parameter in $Parameters) {
    $ParamText = @'
        It 'Has a Parameter called $Parameter' {
            $Function.Parameters.Keys.Contains('$Parameter') | Should Be 'True'
            }
        It '$Parameter Parameter is Identified as Mandatory being $MandatoryValue' {
            [String]$Function.Parameters.$Parameter.Attributes.Mandatory | Should be $Mandatory
            }
        It '$Parameter Parameter is of String Type' {
            $Function.Parameters.$Parameter.ParameterType.FullName | Should be 'System.String'
            }
        It '$Parameter Parameter is member of ParameterSets' {
            [String]$Function.Parameters.$Parameter.ParameterSets.Keys | Should Be $ParamSets
            }
        It '$Parameter Parameter Position is defined correctly' {
            [String]$Function.Parameters.$Parameter.Attributes.Position | Should be $Positions
            }
        It 'Does $Parameter Parameter Accept Pipeline Input?' {
            [String]$Function.Parameters.$Parameter.Attributes.ValueFromPipeline | Should be $ValueFromPipeline
            }
        It 'Does $Parameter Parameter Accept Pipeline Input by PropertyName?' {
            [String]$Function.Parameters.$Parameter.Attributes.ValueFromPipelineByPropertyName | Should be $PipelineByPropertyName
            }
        It 'Does $Parameter Parameter use advanced parameter Validation? ' {
            $Function.Parameters.$Parameter.Attributes.TypeID.Name -contains 'ValidateNotNullOrEmptyAttribute' | Should Be $VNNEAttribute
            $Function.Parameters.$Parameter.Attributes.TypeID.Name -contains 'ValidateNotNullAttribute' | Should Be $VNNAttribute
            $Function.Parameters.$Parameter.Attributes.TypeID.Name -contains 'ValidateScript' | Should Be $VSAttribute
            $Function.Parameters.$Parameter.Attributes.TypeID.Name -contains 'ValidateRangeAttribute' | Should Be $VRAttribute
            $Function.Parameters.$Parameter.Attributes.TypeID.Name -contains 'ValidatePatternAttribute' | Should Be $VRPattern
            }
        It 'Has Parameter Help Text for $Parameter '{
            $function.Definition.Contains('.PARAMETER $Parameter') | Should Be 'True'
            }
'@

    
    $Mandatory = $($ResolvedFunction.Parameters[$parameter].Attributes.Mandatory)
    $Type      = $($ResolvedFunction.Parameters[$parameter].ParameterType.Name)
    $FullType  = $($ResolvedFunction.Parameters[$parameter].ParameterType.FullName)
    $ParamSets = $($ResolvedFunction.Parameters[$parameter].ParameterSets.Keys)
    $Positions = $($ResolvedFunction.Parameters[$parameter].Attributes.Position)
    $ValueFromPipeline = $($ResolvedFunction.Parameters[$parameter].Attributes.ValueFromPipeline)
    $PipelineByPropertyName = $($ResolvedFunction.Parameters[$parameter].Attributes.ValueFromPipelineByPropertyName)
    $VNNEAttribute = $($ResolvedFunction.Parameters[$parameter].Attributes.TypeID.Name -contains 'ValidateNotNullOrEmptyAttribute')
    $VNNAttribute = $($ResolvedFunction.Parameters[$parameter].Attributes.TypeID.Name -contains 'ValidateNotNullAttribute')
    $VSAttribute = $($ResolvedFunction.Parameters[$parameter].Attributes.TypeID.Name -contains 'ValidateScript')
    $VRAttribute = $($ResolvedFunction.Parameters[$parameter].Attributes.TypeID.Name -contains 'ValidateRangeAttribute')
    $VRPattern = $($ResolvedFunction.Parameters[$parameter].Attributes.TypeID.Name -contains 'ValidatePatternAttribute')

    # Replacing text section
    $ParamText = $ParamText.Replace('$Parameter',$Parameter)
    $ParamText = $ParamText.Replace('$MandatoryValue',$Mandatory)
    $ParamText = $ParamText.Replace('$VNNEAttribute',"'$VNNEAttribute'")
    $ParamText = $ParamText.Replace('$VNNAttribute',"'$VNNAttribute'")
    $ParamText = $ParamText.Replace('$VSAttribute',"'$VSAttribute'")
    $ParamText = $ParamText.Replace('$VRAttribute',"'$VRAttribute'")
    $ParamText = $ParamText.Replace('$VRPattern',"'$VRPattern'")  
    $ParamText = $ParamText.Replace('$Mandatory',"'$Mandatory'")
    $ParamText = $ParamText.Replace('$ParamSets',"'$ParamSets'")
    $ParamText = $ParamText.Replace('$Positions',"'$Positions'")
    $ParamText = $ParamText.Replace('$ValueFromPipeline',"'$ValueFromPipeline'")
    $ParamText = $ParamText.Replace('$PipelineByPropertyName',"'$PipelineByPropertyName'")
    $ParamText = $ParamText.Replace("String Type","$Type Type")
    $ParamText = $ParamText.Replace("System.String",$FullType)

    
    $SB.AppendLine($ParamText) | Out-Null

    Write-Verbose -Message "Added the Parameter Pester Tests for the $Parameter Parameter"
    }
$ContextClose = @'
    }
'@

$SB.AppendLine($ContextClose) | Out-Null
}
$HelpTests = @'
    Context "Function $($function.Name) - Help Section" {

            It "Function $($function.Name) Has show-help comment block" {

                $function.Definition.Contains('<#') | should be 'True'
                $function.Definition.Contains('#>') | should be 'True'
            }

            It "Function $($function.Name) Has show-help comment block has a.SYNOPSIS" {

                $function.Definition.Contains('.SYNOPSIS') -or $function.Definition.Contains('.Synopsis') | should be 'True'

            }

            It "Function $($function.Name) Has show-help comment block has an example" {

                $function.Definition.Contains('.EXAMPLE') | should be 'True'
            }

            It "Function $($function.Name) Is an advanced function" {

                $function.CmdletBinding | should be 'True'
                $function.Definition.Contains('param') -or  $function.Definition.Contains('Param') | should be 'True'
            }
    
    }
'@

Write-Verbose -Message "Added the Closing lines for the Parameters Section"


$SB.AppendLine($HelpTests) | Out-Null

$DescribeClose = @'

 }

'@
    $SB.AppendLine($DescribeClose) | Out-Null
    Write-Verbose -Message "Added the Ending Line to the StringBuilder Variable"

    New-Item $Tests -ItemType File -Force | Out-Null
    Write-Verbose "File $Tests was created"
    Set-Content $Tests -Value $($SB.ToString()) -Force -Encoding UTF8
    Write-Verbose -Message "Added the Content to the $Tests File and Set the Encoding to UTF8"

    New-Item $FunctionalTests -ItemType File -Force | Out-Null
    Write-Verbose "File $FunctionalTests was created"
    }

}
function New-ModulePesterTest {
<#
.SYNOPSIS
Creates a ps1 file that includes a subset of basic pester tests

.DESCRIPTION
As synopsis

.PARAMETER ModuleName

.PARAMETER OutPath

.EXAMPLE
New-ModulePesterTests -ModuleName SPCSPS

This will get the SPCSPS module and the path that is asocciated with it and then create a ps1 file that contains a base level of Pester Tests         
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param (
            [String]$ModuleName,
            [String]$OutPath
          )
    if ($PSCmdlet.ShouldProcess($OutPath,"Creating Module Pester test File for $ModuleName"))
{
    $FullModulePesterTests = Get-Content -Path "$(Split-path -Path ((Get-Module PesterHelpers).Path) -Parent)\Full-ModuleTests.txt"
    $NormModulePesterTests = Get-Content -Path "$(Split-path -Path ((Get-Module PesterHelpers).Path) -Parent)\Norm-ModuleTests.txt"
    $MinModulePesterTests = Get-Content -Path "$(Split-path -Path ((Get-Module PesterHelpers).Path) -Parent)\Min-ModuleTests.txt"

    New-Item -Path "$OutPath\$ModuleName.Full.Tests.ps1" -ItemType File -Force | Out-Null
    Set-Content -Path "$OutPath\$ModuleName.Full.Tests.ps1" -Value $FullModulePesterTests -Encoding UTF8 | Out-Null
    
    New-Item -Path "$OutPath\$ModuleName.Norm.Tests.ps1" -ItemType File -Force | Out-Null
    Set-Content -Path "$OutPath\$ModuleName.Norm.Tests.ps1" -Value $NormModulePesterTests -Encoding UTF8 | Out-Null
    
    New-Item -Path "$OutPath\$ModuleName.Min.Tests.ps1" -ItemType File -Force | Out-Null
    Set-Content -Path "$OutPath\$ModuleName.Min.Tests.ps1" -Value $MinModulePesterTests -Encoding UTF8 | Out-Null
    }

}

Export-ModuleMember -Function 'Export-AllModuleFunction','Export-Function','New-FunctionFile','New-FunctionPesterTest','New-ModulePesterTest'
