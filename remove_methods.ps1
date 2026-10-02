$content = Get-Content -Path 'e:\Softwares\Watchroom Koyilandy\lib\screens\duty_register_screen.dart' -Raw
$methods = @('_autoAssignSFRO', '_autoAssignFRO', '_autoAssignFROMales', '_autoAssignAccessories', '_autoAssignDrivers', '_autoAssignKHG')
foreach ($method in $methods) {
    $pattern = '(?s)  void ' + $method + '\(\) \{.*?^\s*\}\r?\n'
    # Actually regex won't balance braces. Let's write a simple brace matcher.
}
