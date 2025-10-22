= Part 1

We have a lamp with $P = 25 "W"$ and $epsilon = 0.20$.
This yields the radiant flux:
$ Phi = P epsilon = 25 "W" dot 0.20 = 5 "W" $
In 1 second, we can calculate the amount of energy emitted:
$ Q = Phi t = 5 "W" dot 1 "s" = 5 "J" $
We then calculate the amount of energy per photon with $lambda = 500$:
$ E = (h c)/lambda = (6.626 dot 10^(-34) "Js" dot 2.9976 dot 10^8 "m/s")/(500 dot 10^(-9) "m") approx 3.97 dot 10^(-19) "J" $
We can then calculate the number of photons:
$ "#Photons" = Q / E = (5 "J") / (3.97 dot 10^(-19) "J") approx 1.26 dot 10^19 $

= Part 2
Since we assume ideal conditions, $epsilon = 1$.
With voltage and current we can calculate the power of the bulb:
$ P = U V = 2.4 "V" dot 0.7 "A" = 1.68 "W" $
Since $epsilon = 1$ this is equal to the radiant flux:
$ Phi = epsilon P = P = 1.68 "W" $

Since the light source is isotropic, we can calculate the radiant intensity since the light source is a perfect sphere:
$ I = ("d" Phi)/("d" omega) = Phi / Omega = (1.68 "W") / (4 pi) approx 0.134 "W" $

To determine the radiant exitance, we need the area of the bulb:
$ A = 4 pi r^2 = 4 pi (1 "cm")^2 = 4 pi "cm"^2 $

Since the light is emitted equally over all areas of the sphere, the radiant exitance is:
$ M = ("d" Phi)/("d" A) = Phi / A = (1.68 "W")/(4 pi "cm"^2) approx 0.1337 "W"/("cm"^2) = 1337 "W"/"m"^2 $

We can calculate the amount of energy emitted in 5 minutes using the radiant flux as it is constant:
$ E = Phi t = 1.68 "J/s" dot 300 "s" = 504 "J" $

= Part 3
We assume the pupil to be a perfect disc looking directly at the bulb.

We want to project the pupil onto the bulb to find the solid angle of the bulb which light hits the pupil.
We determine the angle from the center of the bulb to the top of the pupil.

$ theta_1 = tan^(-1)((1/2 d) / r) = tan^(-1)((1/2 dot 6 dot 10^(-3) "m") / (1 "m" + 0.005 "m")) approx 0.0030 $

We can then integrate to find the solid angle:

$ omega &= integral_0^(2 pi) integral_0^(theta_1) sin theta dif theta dif phi \ &= integral_0^(2 pi) dif phi integral_(cos theta_1)^(cos 0) dif (cos theta) \ &= 2 pi (cos 0 - cos theta_1) \ &= 2 pi (1 - cos(0.0030)) \ &= 0.000028 $

Using this solid angle and the intensity found earlier, we can calculate the flux hitting the pupil:

$ Phi = I dot omega = 0.134 "W" dot 0.000028 = 0.000003752 "W" $

Using the area of the pupil we can get the irradiance:
$ E = Phi / A = (0.000003752 "W")/(pi (3 dot 10^(-3) "m")^2) approx 0.1326 "W"/"m"^2 $



= Part 4

$ Phi = P epsilon = 200 "W" dot 0.20 = 40 "W" $

We assume that light is emitted equally in all directions. Then the intensity of the light becomes:
$ I = (dif Phi)/(dif omega) = Phi / Omega = (40 "W")/(4 pi) approx 3.183 "W" $

Using the intensity we can calculate the irradiance 2 meters away. We look at the point directly beneath the light, such that $theta = 0$ and $cos theta = 1$:
$ E = I (cos theta)/r^2 = I/r^2 = (3.183 "W")/(2 "m")^2 = (3.183 "W")/(4 "m"^2) = 0.796 "W"/"m"^2 $

We then calculate the illuminance:
$ "Illuminance" = "Irradiance" dot 685 "lm"/"W" dot V(650 "nm") = 0.796 "W"/"m"^2 dot 685 "lm"/"W" dot 0.1 = 54.526 "lm"/"m"^2 $

= Part 5

The irradiance/illuminance at the screen is equal on either side:
$ E_1 = E_2 $

Assuming each can be considered a point light, we can calculate the irradiance:
$ E_1 &= I_1/r_1^2 \
  E_2 &= I_2/r_2^2 $

Therefore:
$ I_1/r_1^2 = I_2/r_2^2 => I_2 = I_1 r_2^2/r_1^2$

Since the mapping from irradiance to illuminance is linear (given some $lambda$) this also holds for the illuminance values:
$ I_2 = I_1 r_2^2/r_1^2 = 40 "lm/sr" (65 "cm")^2/(35 "cm")^2 = 137.96 "lm/sr" $


= Part 6
$ B = L pi = 5000 pi "W"/"m"^2 $

$ Phi = B * A = 5000 pi "W"/"m"^2 dot (0.10 "m")^2 = 50 pi "W" $

= Part 7

$ B &= integral_(2 pi) L cos theta dif omega
\ &= integral_(2 pi) 6000 cos theta "W/(m² sr)" cos theta dif omega
\ &= 6000 "W/(m² sr)" integral_(2 pi) cos theta cos theta dif omega
\ &= 6000 "W/(m² sr)" integral_0^(2 pi) integral_0^(pi/2) cos theta cos theta sin theta dif theta dif phi
\ &= 6000 "W/(m² sr)" 2 pi integral_0^(pi/2) cos theta cos theta sin theta dif theta
\ &= 6000 "W/(m² sr)" 2 pi integral_(cos 0)^(cos pi/2) cos theta (- cos theta) dif (cos theta)
\ &= 6000 "W/(m² sr)" 2 pi integral_(cos 0)^(cos pi/2) -(cos theta)^2 dif (cos theta)
\ &= 6000 "W/(m² sr)" 2 pi integral_(1)^(0) -x^2 dif x
\ &= 6000 "W/(m² sr)" 2 pi [-1/3 x^3]_1^0 
\ &= 6000 "W/(m² sr)" 2 pi (0 - (-1/3)) 
\ &= 6000 "W/(m² sr)" 2 pi 1/3 \ &= 4000 pi "W/(m²)" $

= Part 8 (optional)

= Part 9 (optional)
