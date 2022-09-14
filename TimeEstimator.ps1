
class TimeEstimator {

    $Total

    hidden $Ticks = 0
    static hidden $bufferSize = 100
    hidden $Timeline = (New-Object decimal[] ([TimeEstimator]::bufferSize))
    hidden [double] $Rate = 0.0
    hidden $ComputeInterval

    TimeEstimator($Total) {
        $this.Total = $Total
        $this.ComputeInterval = [int]([Math]::Min(100, $Total / 10))
    }

    TimeEstimator([int]$Total, [int]$ComputeInterval) {
        $this.Total = $Total
        $this.ComputeInterval = [Math]::Max($ComputeInterval, 15)
    }
    
    [void] Tick() {
        $this.Ticks++
        $this.Timeline[$this.Ticks % [TimeEstimator]::bufferSize] = [DateTime]::Now.Ticks
        
        if ($this.Ticks % $this.ComputeInterval -eq 0) {
            # Generate a time estimate based on work done in the last 30 seconds
            # TODO improve by doing a rolling weighted average based on how many have been performed minute over minute since the beginning, ignoring minutes which fall outside the stddev for the last 2 minutes
            $measurement = ($this.Timeline.Where({ $_ -ne 0 }) | measure -Minimum -Maximum)
            $done_this_minute = $measurement.Count
            $this.Rate = ([double]($measurement.Count) / ([decimal]($measurement.Maximum - $measurement.Minimum) / [timespan]::TicksPerSecond))
            
        }
    }

    [string] GetStatusQuote() {
        if ($this.Rate -eq 0.0) { return 'Too early to tell.' }
        return "More than {0}/{1} completed. Rate: {2:N2} / sec." -f $this.Ticks, $this.Total, $this.Rate
    }

    [int] GetSecondsRemaining() {
        if ($this.Rate -eq 0.0) { return [int]::MaxValue }
        return  [Math]::Max(0, [Math]::Min([int]::MaxValue, (($this.Total - $this.Ticks) / $this.Rate)))
    }

    [int] GetPercentage () {
        filter Percentage { 
            param ([ValidateRange(0,[int32]::MaxValue)]$count=0, 
                   [ValidateRange(1,[int32]::MaxValue)]$total=1) 
            [Math]::Min(100, [Math]::Round(($count/$total) * 100))
        }

        return (Percentage -count ($this.Ticks) -total ($this.Total))
    }
}


# 50k itteration test loop
$recordCount = 50 * 1000

$estimator = [TimeEstimator]::new($recordCount, 100)
1..$recordCount | foreach {
    
    $estimator.Tick()
    Write-Progress -Activity "Stirring this mess up.." `
        -Status ($estimator.GetStatusQuote()) `
        -PercentComplete ($estimator.GetPercentage()) `
        -SecondsRemaining ($estimator.GetSecondsRemaining())
}

