double clamp01(double value) => value < 0
    ? 0
    : value > 1
    ? 1
    : value;

double smoothstep(double t) => t * t * (3 - 2 * t);
