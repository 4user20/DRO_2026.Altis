params ["_side"];
switch (_side) do {
    case east: {0};
    case west: {1};
    case resistance: {2};
    default {-1};
}
