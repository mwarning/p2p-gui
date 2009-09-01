module utils.Timer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.core.Thread;

import webcore.Logger;
static import Utils = utils.Utils;


/*
* Call a function in float_time seconds with an interval of float_interval.
* A function can only be once in the timers array.
*/
public void add(void function() caller, float float_time, float float_interval = 0)
{
    add(Utils.toDg(caller), float_time, float_interval);
}

public bool add(void delegate() caller, float float_time, float float_interval = 0)
{
    //convert to number of time steps
    uint time = cast(uint) (float_time / time_step);
    uint interval = cast(uint) (float_interval / time_step);
    
    debug(Timer)
        Logger.addDebug("Timer: Make call in {} seconds in {} second intervals.", float_time, float_interval);
    
    if(time == 0)
    {
        Logger.addError("Timer: Cannot register timer. Time frame too short!");
        return false;
    }
    
    if(float_interval != 0.0 && interval == 0)
    {
        Logger.addError("(E) Timer: Cannot register timer. Time interval too short!");
        return false;
    }
    
    //free position for the event
    int pos = -1;
    
    //check timers for the first free place or a doublicate caller
    for(auto i = 0; i < end; i++)
    {
        if(timers[i] is null)
        {
            if(pos < 0)
                pos = i;
        }
        else if(timers[i].caller == caller) //duplicate event, will be overwritten
        {
            timers[i] = null;
            if(i < pos) pos = i;
            break;
        }
    }
    
    if(pos >= 0)
    {
        timers[pos] = new TWrapper(caller, counter + time, interval);
        return true;
    }
    else if((end + 1) < timers.length) //need more room
    {
        timers[end] = new TWrapper(caller, counter + time, interval);
        end++;
        return true;
    }
    else
    {
        Logger.addFatal("Timer: Cannot register timer. Array is full!");
        return false;
    }
}


private class TWrapper
{
    uint interval; //call every intervals
    uint time;
    private void delegate() caller;
    
    this(void delegate() caller, uint time, uint interval = 0)
    {
        this.caller = caller;
        this.interval = interval;
        this.time = time;
    }
    
    void run()
    {
        caller();
    }
}

public void remove(void delegate() caller, bool all = false)
{
    for(auto i = 0; i < end; i++)
    {
        if(    timers[i] !is null
            && timers[i].caller.funcptr == caller.funcptr
            && timers[i].caller.ptr == caller.ptr
        )
        {
            timers[i] = null;
            if(all == false) return;
        }
    }
}

/*
* Remove all entries associated with this object.
*/
public void remove(Object o)
{
    for(auto i = 0; i < end; i++)
    {
        if(timers[i] !is null && timers[i].caller.ptr == cast(void*) o)
        {
            timers[i] = null;
        }
    }
}

private
{
    bool run = false;
    uint end = 0; //this is max index we iterate over timers
    TWrapper[256] timers;

    const float time_step = 0.5; //time resolution
    uint counter = 0;
}

public void shutdown()
{
    run = false;
}

public void timer_loop(void delegate(void delegate()) add_task)
{
    if(run)
    {
        Logger.addWarning("Timer: Timer loop already running!");
        return;
    }
    
    run = true;
    Logger.addInfo("Timer: Start timer loop.");
    
    while(run)
    {
        Thread.sleep(time_step);
        counter++;
        
        for(auto i = 0; i < end; i++)
        {
            auto timer = timers[i];
            if(timer is null || timer.time > counter)
                continue;
            
            add_task(&timer.run);
            
            if(timer.interval)
            {
                timer.time += timer.interval;
            }
            else
            {
                //remove event
                timers[i] = null;
            }
        }
    }
    
    timers[] = null;
    end = 0;
    counter = 0;
}
