
struct cflp_data
    """
    data type to store problem data 
    constructor includes data tests and computation of 
    derived parameters
    """
    cost_fix::Vector{Float64}
    cost_var::Matrix{Float64}
    capacity::Vector{Int64}
    demand::Vector{Int64} 
    m::Int64
    n::Int64
    bigM_fac::Float64
    bigM_customer::Float64
    
    
    function cflp_data(cost_fix, cost_var, capacity, demand)
        """
        tests data for simplicity we just test that the overall capacity is greater 
        or equal to the overall demand and check the dimensions
        1 = capacity constraints
        2 = equal dimensions of fix cost and capacity
        3 = equal dimensions of var cost (column) and capacity
        4 = equal dimensions of var cost (row) and demand
        """
        
        if sum(demand) > sum(capacity) 
            throw(DomainError(sum(demand), "Demand exceeds capacity"))
        end
        
        if length(capacity) != length(cost_fix)
            throw(DomainError(length(capacity), 
                    "Dimension capacity and fix cost dont match"))
        end     
        
        if length(capacity) != size(cost_var)[2]
            throw(DomainError(length(capacity),
                    "Dimension capacity and variable cost dont match"))
        end
        
        if length(demand) != size(cost_var)[1]
            throw(DomainError(length(demand), 
                    "Dimension demand and variable cost dont match"))
        end
        
        # we add dimensions and upper bounds to the data structure
        # in particular other upper bounds might be computable faster
        m = length(capacity)
        n = length(demand)
        bigM_fac = sum(cost_var) + 1
        bigM_customer = findmax(cost_var)[1] + 1
        
        return new(cost_fix, cost_var, capacity, demand, m, n, bigM_fac, bigM_customer)
    end 
end