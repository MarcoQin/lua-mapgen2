--[[
 * Implementation of the Park Miller (1988) "minimal standard" linear
 * congruential pseudo-random number generator.
 *
 * For a full explanation visit: http://www.firstpr.com.au/dsp/rand31/
 *
 * The generator uses a modulus constant (m) of 2^31 - 1 which is a
 * Mersenne Prime number and a full-period-multiplier of 16807.
 * Output is a 31 bit unsigned integer. The range of values output is
 * 1 to 2,147,483,646 (2^31-1) and the seed must be in this range too.
 *
 * David G. Carta's optimisation which needs only 32 bit integer math,
 * and no division is actually *slower* in flash (both AS2 & AS3) so
 * it's better to use the double-precision floating point version.
 *
 * @author Michael Baczynski, www.polygonal.de
 ]]

 local class = require("as3delaunay/middleclass")

 PM_PRNG = class("PM_PRNG")

 function PM_PRNG:init(seed)
     -- set seed with a 31 bit unsigned integer
     -- between 1 and 0X7FFFFFFE inclusive. don't use 0!
     self.seed = seed or 1
 end

 function PM_PRNG:nextInt()
     return self:gen()
 end

 function PM_PRNG:nextDouble()
     return self:gen() / 2147483647
 end

 function PM_PRNG:nextIntRange(min, max)
     min = min - 0.4999
     max = max + 0.4999
    return math.floor(0.5 + min + ((max - min) * self:nextDouble()))
 end

 function PM_PRNG:nextDoubleRange(min, max)
     return min + ((max - min) * self:nextDouble())
 end

 function PM_PRNG:gen()
     self.seed = (self.seed * 16807) % 2147483647
     return self.seed
 end
