module rt.sort;


void sort(T)(T[] array)
{
    int compare (ref T left, ref T right)
    {
        if(left < right) return -1;
        if(left > right) return 1;
        if(left == right) return 0;
        return 0;
    }
    sort(array, &compare);
}

void sort(T)(T[] array, scope int delegate(ref T, ref T) dg)
{
    sort(array, 0, cast(int) array.length - 1, dg);
}

void sort(T)(T[] array, int lower, int upper, scope int delegate(ref T, ref T) dg)
{
    // Check for non-base case
    if (lower >= upper)
    {
        return;
    }

    // Split and sort partitions
    auto split = pivot(array, lower, upper, dg);
    sort(array, lower, split - 1, dg);
    sort(array, split + 1, upper, dg);
}


int pivot(T)(T[] array, int lower, int upper, scope int delegate(ref T, ref T) dg)
{
   // Pivot with first element
    auto left = lower + 1;
    auto pivot = array[lower];
    auto right = upper;

    // Partition array elements
    while (left <= right)
    {
        // Find item out of place
        while ((left <= right) && (dg(array[left], pivot) <= 0))
        {
            ++left;
        }

        while ((left <= right) && (dg(array[right], pivot) > 0))
        {
            --right;
        }

        // Swap values if necessary
        if (left < right)
        {
            swap(array, left, right);
            ++left;
            --right;
        }
    }

    // Move pivot element
    swap(array, lower, right);
    return right;
}

void swap(T)(T[] array, int left, int right)
{
     auto swap = array[left];
     array[left] = array[right];
     array[right] = swap;
}
