# .Net methods for hiding/showing the console in the background as well as moving and resizing it
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Window {
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool DestroyWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
}

public struct RECT
{
    public int Left;        // x position of upper-left corner
    public int Top;         // y position of upper-left corner
    public int Right;       // x position of lower-right corner
    public int Bottom;      // y position of lower-right corner
}
"@
Add-Type -AssemblyName System.Core, System.Windows.Forms

function Show-Console {
    # Function to show the console and restore from minimized state
    param (
        $consolePtr,
        [switch]$Immediate = $false,
        [switch]$moveToTopLeft = $false
    )

    # If no handle is passed in, get the current console window handle
    if ($consolePtr -eq $null) {
        $consolePtr = [Window]::GetConsoleWindow()
    }

    <#
    Options for the ShowWindow function:
    Hide = 0,
    ShowNormal = 1,
    ShowMinimized = 2,
    ShowMaximized = 3,
    Maximize = 3,
    ShowNormalNoActivate = 4,
    Show = 5,
    Minimize = 6,
    ShowMinNoActivate = 7,
    ShowNoActivate = 8,
    Restore = 9,
    ShowDefault = 10,
    ForceMinimized = 11
    #>

    # Show the window
    [void][Window]::ShowWindow($consolePtr, 5)

    # Restore the window if it is minimized
    if (Get-ConsoleMinimized $consolePtr) {
        # Restore the window
		[void][Window]::ShowWindow($consolePtr, 9)

        # Wait for the restore animation to completeonly if Immediate is false
        if (-not $Immediate) {
            Sleep -Milliseconds 300
        }
	}

    # If defined, move the console to the top left of the screen
    if ($moveToTopLeft) {
        Move-ConsoleToTopLeft $consolePtr
    }
}
Export-ModuleMember Show-Console

function Hide-Console {
    # Function to minimize (if not already) then hide the console
    param ( 
        $consolePtr,
        [switch]$Immediate = $false,
        [int]$delay = 0,
        [int]$duration = 0
    )
        
    # If no handle is passed in, get the current console window handle
    if ($consolePtr -eq $null) {
        $consolePtr = [Window]::GetConsoleWindow()
    }

    # Wait for delay is speified
    if ($delay -gt 0) {
        Start-Sleep -Milliseconds $delay
    }

    # Minimize the window first if it is not already
    if (-not (Get-ConsoleMinimized $consolePtr)) {
        # Minimize the window
		[void][Window]::ShowWindow($consolePtr, 6)

        # Wait for minimize animation to complete only if Immediate is false
        if (-not $Immediate) {
            Sleep -Milliseconds 300
        }
	}
        
    # Hide the window
    [void][Window]::ShowWindow($consolePtr, 0)

    # If defined, wait the duration then show the window once more
    if ($duration -gt 0) {
        Sleep -Milliseconds $duration
        Show-Console $consolePtr
    }
}
Export-ModuleMember Hide-Console

function Close-Window {
    # Function to check if a given window handle still points to a valid window
    param ( $consolePtr )
        
    # If no handle is passed in, get the current console window handle
    if ($consolePtr -eq $null) {
        $consolePtr = [Window]::GetConsoleWindow()
    }

    # CloseWindow will do exactly as it says
    [Window]::DestroyWindow($consolePtr)
}
Export-ModuleMember Close-Window

function Get-WindowExists {
    # Function to check if a given window handle still points to a valid window
    param ( $consolePtr )
        
    # If no handle is passed in, get the current console window handle
    if ($consolePtr -eq $null) {
        $consolePtr = [Window]::GetConsoleWindow()
    }

    # IsWindow will return whether the given handle points to a valid window
    [Window]::IsWindow($consolePtr)
}
Export-ModuleMember Get-WindowExists

function Move-ConsoleToTopLeft {
    # Function to move the console to the top left corner of the screen and retain current size
    param ( $consolePtr )
        
    # If no handle is passed in, get the current console window handle
    if ($consolePtr -eq $null) {
        $consolePtr = [Window]::GetConsoleWindow()
    }

    # Get the current RECT of the window
    $rcWindow = New-Object RECT
    [void][Window]::GetWindowRect($consolePtr, [ref]$rcWindow)

    # Move window to the top left of the screen, maintaining the same size
    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Size
    [void][Window]::MoveWindow($consolePtr, 0, 0, $workingArea.Width, $workingArea.Height)
}
Export-ModuleMember Move-ConsoleToTopLeft

function Get-ConsoleMinimized {
    # Function to check if a window is currently minimized
    param ( 
        $consolePtr
    )
        
    # If no handle is passed in, get the current console window handle
    if ($consolePtr -eq $null) {
        $consolePtr = [Window]::GetConsoleWindow()
    }

    # IsIconic will return whether the window is minimized or not
    [Window]::IsIconic($consolePtr)
}
Export-ModuleMember Get-ConsoleMinimized