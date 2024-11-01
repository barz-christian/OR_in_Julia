function test_cflp_solution(data::cflp_data, solution::cflp_solution, k, verbose=false)
    """
    simple test solution if 
    1) demand is allocated
    2) capacity not exceeded
    3) maximal number of open facility
    4) number of open facility at least 1
    """
    
    
    # test if all demand is allocated
    test1 = all([sum(solution.assignment[:,i]) == data.demand[i] for i in 1:data.n])
    
    # test capacity allocation
    test2 = all([data.capacity[j] >= sum(solution.assignment[j,:]) for j in 1:data.m])

    # test if number of open facilities is less than k
    test3 = sum(solution.open_facilities) <= k 
        
    # test if at least one facility is open
    test4 = sum(solution.open_facilities) >= 1

    if verbose
        println([test1, test2, test3, test4])
    end
    
    return all([test1, test2, test3, test4])
end